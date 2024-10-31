use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::eth_rpc::IEthRPC;
use contracts::kakarot_core::{KakarotCore, KakarotCore::KakarotCoreImpl};
use core::num::traits::zero::Zero;
use core::ops::SnapshotDeref;
use core::starknet::storage::StoragePointerReadAccess;
use core::starknet::syscalls::{deploy_syscall};
use core::starknet::syscalls::{emit_event_syscall};
use core::starknet::{EthAddress, get_block_info, SyscallResultTrait};
use crate::errors::{ensure, EVMError};
use crate::model::{Address, AddressTrait, Environment, Account, AccountTrait};
use crate::model::{Transfer};
use crate::state::{State, StateTrait};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use utils::constants::BURN_ADDRESS;
use utils::constants;
use utils::set::SetTrait;


/// Commits the state changes to Starknet.
///
/// # Arguments
///
/// * `state` - The state to commit.
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
pub fn commit(ref state: State) -> Result<(), EVMError> {
    commit_accounts(ref state)?;
    transfer_native_token(ref state)?;
    emit_events(ref state)?;
    commit_storage(ref state)
}

/// Deploys a new EOA contract.
///
/// # Arguments
///
/// * `evm_address` - The EVM address of the EOA to deploy.
pub fn deploy(evm_address: EthAddress) -> Result<Address, EVMError> {
    // Unlike CAs, there is not check for the existence of an EOA prealably to calling
    // `EOATrait::deploy` - therefore, we need to check that there is no collision.
    let mut is_deployed = evm_address.is_deployed();
    ensure(!is_deployed, EVMError::Collision)?;

    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let uninitialized_account_class_hash = kakarot_state.uninitialized_account_class_hash();
    let calldata: Span<felt252> = [1, evm_address.into()].span();

    let (starknet_address, _) = deploy_syscall(
        uninitialized_account_class_hash,
        contract_address_salt: evm_address.into(),
        calldata: calldata,
        deploy_from_zero: false
    )
        .unwrap_syscall();

    Result::Ok(Address { evm: evm_address, starknet: starknet_address })
}

pub fn get_bytecode(evm_address: EthAddress) -> Span<u8> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let starknet_address = kakarot_state.address_registry(evm_address);
    if starknet_address.is_non_zero() {
        let account = IAccountDispatcher { contract_address: starknet_address };
        account.bytecode()
    } else {
        [].span()
    }
}

/// Populate an Environment with Starknet syscalls.
pub fn get_env(origin: Address, gas_price: u128) -> Environment {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let kakarot_storage = kakarot_state.snapshot_deref();
    let block_info = get_block_info().unbox();

    // tx.gas_price and env.gas_price have the same values here
    // - this is not always true in EVM transactions
    Environment {
        origin: origin,
        gas_price,
        chain_id: kakarot_state.eth_chain_id(),
        prevrandao: kakarot_storage.Kakarot_prev_randao.read(),
        block_number: block_info.block_number,
        block_gas_limit: constants::BLOCK_GAS_LIMIT,
        block_timestamp: block_info.block_timestamp,
        coinbase: kakarot_storage.Kakarot_coinbase.read(),
        base_fee: kakarot_storage.Kakarot_base_fee.read(),
        state: Default::default(),
    }
}

/// Fetches the value stored at the given key for the corresponding contract accounts.
/// If the account is not deployed (in case of a create/deploy transaction), returns 0.
/// # Arguments
///
/// * `account` The account to read from.
/// * `key` The key to read.
///
/// # Returns
///
/// A `Result` containing the value stored at the given key or an `EVMError` if there was an error.
pub fn fetch_original_storage(account: @Account, key: u256) -> u256 {
    let is_deployed = account.evm_address().is_deployed();
    if is_deployed {
        return IAccountDispatcher { contract_address: account.starknet_address() }.storage(key);
    }
    0
}

/// Fetches the balance of the given address.
///
/// # Arguments
///
/// * `self` - The address to fetch the balance of.
///
/// # Returns
///
/// The balance of the given address.
pub fn fetch_balance(self: @Address) -> u256 {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    kakarot_state.eth_get_balance(*self.evm)
}


/// Commits the account changes to Starknet.
///
/// # Arguments
///
/// * `state` - The state containing the accounts to commit.
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
fn commit_accounts(ref state: State) -> Result<(), EVMError> {
    let mut account_keys = state.accounts.keyset.to_span();
    for evm_address in account_keys {
        let account = state.accounts.changes.get(*evm_address).deref();
        commit_account(@account, ref state);
    };
    return Result::Ok(());
}

/// Commits the account to Starknet by updating the account state if it
/// exists, or deploying a new account if it doesn't.
///
/// # Arguments
/// * `self` - The account to commit
/// * `state` - The state, modified in the case of selfdestruct transfers
///
/// # Returns
///
/// `Ok(())` if the commit was successful, otherwise an `EVMError`.
fn commit_account(self: @Account, ref state: State) {
    if self.evm_address().is_precompile() {
        return;
    }

    // Case new account
    if !self.evm_address().is_deployed() {
        deploy(self.evm_address()).expect('account deployment failed');
    }

    // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
    // and burn any leftover balance.
    if (self.is_selfdestruct() && self.is_created()) {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let burn_starknet_address = kakarot_state
            .get_starknet_address(BURN_ADDRESS.try_into().unwrap());
        let burn_address = Address {
            starknet: burn_starknet_address, evm: BURN_ADDRESS.try_into().unwrap()
        };
        state
            .add_transfer(
                Transfer { sender: self.address(), recipient: burn_address, amount: self.balance() }
            )
            .expect('Failed to burn on selfdestruct');
        return;
    }

    if !self.has_code_or_nonce() {
        // Nothing to commit
        return;
    }

    // Write updated nonce and storage
    //TODO: storage commits are done in the State commitment as they're not part of the account
    //model in SSJ
    let starknet_account = IAccountDispatcher { contract_address: self.starknet_address() };
    starknet_account.set_nonce(*self.nonce);

    //Storage is handled outside of the account and must be committed after all accounts are
    //committed.
    if self.is_created() {
        starknet_account.write_bytecode(self.bytecode());
        starknet_account.set_code_hash(self.code_hash());
        //TODO: save valid jumpdests https://github.com/kkrt-labs/kakarot-ssj/issues/839
    }
    return;
}

/// Iterates through the list of pending transfer and triggers them
fn transfer_native_token(ref self: State) -> Result<(), EVMError> {
    let kakarot_state = KakarotCore::unsafe_new_contract_state();
    let native_token = kakarot_state.get_native_token();
    while let Option::Some(transfer) = self.transfers.pop_front() {
        IERC20Dispatcher { contract_address: native_token }
            .transfer_from(transfer.sender.starknet, transfer.recipient.starknet, transfer.amount);
    };
    Result::Ok(())
}

/// Iterates through the list of events and emits them.
fn emit_events(ref self: State) -> Result<(), EVMError> {
    while let Option::Some(event) = self.events.pop_front() {
        let mut keys = Default::default();
        let mut data = Default::default();
        Serde::<Array<u256>>::serialize(@event.keys, ref keys);
        Serde::<Array<u8>>::serialize(@event.data, ref data);
        emit_event_syscall(keys.span(), data.span()).unwrap_syscall();
    };
    return Result::Ok(());
}

/// Commits storage changes to the KakarotCore contract by writing pending
/// state changes to Starknet Storage.
/// commit_storage MUST be called after commit_accounts.
fn commit_storage(ref self: State) -> Result<(), EVMError> {
    let mut storage_keys = self.accounts_storage.keyset.to_span();
    for state_key in storage_keys {
        let (evm_address, key, value) = self.accounts_storage.changes.get(*state_key).deref();
        let mut account = self.get_account(evm_address);
        // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
        if account.is_selfdestruct() && account.is_created() {
            continue;
        }
        IAccountDispatcher { contract_address: account.starknet_address() }
            .write_storage(key, value);
    };
    Result::Ok(())
}

#[cfg(test)]
mod tests {
    use core::starknet::{ClassHash};
    use crate::backend::starknet_backend;
    use crate::model::account::Account;
    use crate::model::{Address, Event};
    use crate::state::{State, StateTrait};
    use crate::test_utils::{
        setup_test_environment, uninitialized_account, account_contract, register_account
    };
    use crate::test_utils::{evm_address};
    use snforge_std::{
        test_address, start_mock_call, get_class_hash, spy_events, EventSpyTrait,
        Event as StarknetEvent
    };
    use snforge_utils::snforge_utils::{
        assert_not_called, assert_called, EventsFilterBuilderTrait, ContractEventsTrait
    };
    use super::{commit_storage, emit_events};
    use utils::helpers::compute_starknet_address;
    use utils::traits::bytes::U8SpanExTrait;

    // Helper function to create a test account
    fn create_test_account(is_selfdestruct: bool, is_created: bool, id: felt252) -> Account {
        let evm_address = (evm_address().into() + id).try_into().unwrap();
        let starknet_address = (0x5678 + id).try_into().unwrap();
        Account {
            address: Address { evm: evm_address, starknet: starknet_address },
            nonce: 0,
            code: [].span(),
            code_hash: 0,
            balance: 0,
            selfdestruct: is_selfdestruct,
            is_created: is_created,
        }
    }

    // Implementation to convert an `Event` into a serialized `StarknetEvent`
    impl EventIntoStarknetEvent of Into<Event, StarknetEvent> {
        fn into(self: Event) -> StarknetEvent {
            let mut serialized_keys = array![];
            let mut serialized_data = array![];
            Serde::<Array<u256>>::serialize(@self.keys, ref serialized_keys);
            Serde::<Array<u8>>::serialize(@self.data, ref serialized_data);
            StarknetEvent { keys: serialized_keys, data: serialized_data }
        }
    }


    mod test_commit_storage {
        use snforge_std::start_mock_call;
        use snforge_utils::snforge_utils::{assert_called_with, assert_not_called};
        use super::{create_test_account, StateTrait, commit_storage};

        #[test]
        fn test_commit_storage_normal_case() {
            let mut state = Default::default();
            let account = create_test_account(false, false, 0);
            state.set_account(account);

            let key = 0x100;
            let value = 0x200;
            state.write_state(account.address.evm, key, value);

            // Mock the write_storage call
            start_mock_call::<()>(account.address.starknet, selector!("write_storage"), ());

            commit_storage(ref state).expect('commit storage failed');

            //TODO(starknet-foundry): verify call args in assert_called
            assert_called_with::<
                (u256, u256)
            >(account.address.starknet, selector!("write_storage"), (key, value));
        }

        #[test]
        fn test_commit_storage_selfdestruct_and_created() {
            let mut state = Default::default();
            let account = create_test_account(true, true, 0);
            state.set_account(account);

            let key = 0x100;
            let value = 0x200;
            state.write_state(account.address.evm, key, value);

            // Mock the write_storage call
            start_mock_call::<()>(account.address.starknet, selector!("write_storage"), ());

            commit_storage(ref state).expect('commit storage failed');

            // Assert that write_storage was not called
            assert_not_called(account.address.starknet, selector!("write_storage"));
        }

        #[test]
        fn test_commit_storage_only_selfdestruct() {
            let mut state = Default::default();
            let account = create_test_account(true, false, 0);
            state.set_account(account);

            let key = 0x100;
            let value = 0x200;
            state.write_state(account.address.evm, key, value);

            // Mock the write_storage call
            start_mock_call::<()>(account.address.starknet, selector!("write_storage"), ());

            commit_storage(ref state).expect('commit storage failed');

            // Assert that write_storage was called
            assert_called_with::<
                (u256, u256)
            >(account.address.starknet, selector!("write_storage"), (key, value));
        }

        #[test]
        fn test_commit_storage_multiple_accounts() {
            let mut state = Default::default();

            // Account 0: Normal
            let account0 = create_test_account(false, false, 0);
            state.set_account(account0);

            // Account 1: Selfdestruct and created
            let account1 = create_test_account(true, true, 1);
            state.set_account(account1);

            // Account 2: Only selfdestruct
            let account2 = create_test_account(true, false, 2);
            state.set_account(account2);

            // Set storage for all accounts
            let key = 0x100;
            let value = 0x200;
            state.write_state(account0.address.evm, key, value);
            state.write_state(account1.address.evm, key, value);
            state.write_state(account2.address.evm, key, value);

            // Mock the write_storage calls
            start_mock_call::<()>(account0.address.starknet, selector!("write_storage"), ());
            start_mock_call::<()>(account1.address.starknet, selector!("write_storage"), ());
            start_mock_call::<()>(account2.address.starknet, selector!("write_storage"), ());

            commit_storage(ref state).expect('commit storage failed');

            // Assert that write_storage was called for accounts 1 and 3, but not for account 2
            assert_called_with::<
                (u256, u256)
            >(account0.address.starknet, selector!("write_storage"), (key, value));
            assert_not_called(account1.address.starknet, selector!("write_storage"));
            assert_called_with::<
                (u256, u256)
            >(account2.address.starknet, selector!("write_storage"), (key, value));
        }
    }

    #[test]
    #[ignore]
    //TODO(starknet-fonudry): it's impossible to deploy an un-declared class, nor is it possible to
    //mock_deploy.
    fn test_deploy() {
        // store the classes in the context of the local execution, to be used for deploying the
        // account class
        setup_test_environment();
        let test_address = test_address();

        start_mock_call::<
            ClassHash
        >(test_address, selector!("get_account_contract_class_hash"), account_contract());
        start_mock_call::<()>(test_address, selector!("initialize"), ());
        let eoa_address = starknet_backend::deploy(evm_address())
            .expect('deployment of EOA failed');

        let class_hash = get_class_hash(eoa_address.starknet);
        assert_eq!(class_hash, account_contract());
    }

    #[test]
    #[ignore]
    //TODO(starknet-foundry): it's impossible to deploy an un-declared class, nor is it possible to
    //mock_deploy.
    fn test_account_commit_undeployed_create_should_change_set_all() {
        setup_test_environment();
        let test_address = test_address();
        let evm_address = evm_address();
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );

        let mut state: State = Default::default();

        // When
        let bytecode = [0x1].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let mut account = Account {
            address: Address { evm: evm_address, starknet: starknet_address },
            nonce: 420,
            code: bytecode,
            code_hash: code_hash,
            balance: 0,
            selfdestruct: false,
            is_created: true,
        };
        state.set_account(account);

        start_mock_call::<()>(starknet_address, selector!("set_nonce"), ());
        start_mock_call::<
            ClassHash
        >(test_address, selector!("get_account_contract_class_hash"), account_contract());
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then
        //TODO(starknet-foundry): we should be able to assert this has been called with specific
        //data, to pass in mock_call
        assert_called(starknet_address, selector!("set_nonce"));
        assert_not_called(starknet_address, selector!("write_bytecode"));
    }

    #[test]
    fn test_account_commit_deployed_and_created_should_write_code() {
        setup_test_environment();
        let test_address = test_address();
        let evm_address = evm_address();
        let starknet_address = compute_starknet_address(
            test_address, evm_address, uninitialized_account()
        );
        register_account(evm_address, starknet_address);

        let mut state: State = Default::default();
        let bytecode = [0x1].span();
        let code_hash = bytecode.compute_keccak256_hash();
        let mut account = Account {
            address: Address { evm: evm_address, starknet: starknet_address },
            nonce: 420,
            code: bytecode,
            code_hash: code_hash,
            balance: 0,
            selfdestruct: false,
            is_created: true,
        };
        state.set_account(account);

        start_mock_call::<()>(starknet_address, selector!("write_bytecode"), ());
        start_mock_call::<()>(starknet_address, selector!("set_code_hash"), ());
        start_mock_call::<()>(starknet_address, selector!("set_nonce"), ());
        starknet_backend::commit(ref state).expect('commitment failed');

        // Then the account should have a new code.
        //TODO(starknet-foundry): we should be able to assert this has been called with specific
        //data, to pass in mock_call
        assert_called(starknet_address, selector!("write_bytecode"));
        assert_called(starknet_address, selector!("set_code_hash"));
        assert_called(starknet_address, selector!("set_nonce"));
    }

    #[test]
    fn test_emit_events() {
        // Initialize the state
        let mut state: State = Default::default();

        // Prepare a list of events with different combinations of keys and data
        let evm_events = array![
            Event { keys: array![], data: array![] }, // Empty event
            Event { keys: array![1.into()], data: array![2, 3] }, // Single key, multiple data
            Event {
                keys: array![4.into(), 5.into()], data: array![6]
            }, // Multiple keys, single data
            Event {
                keys: array![7.into(), 8.into(), 9.into()], data: array![10, 11, 12, 13]
            } // Multiple keys and data
        ];

        // Add each event to the state
        for event in evm_events.clone() {
            state.add_event(event);
        };

        // Emit the events and assert that no events are left in the state
        let mut spy = spy_events();
        emit_events(ref state).expect('emit events failed');
        assert!(state.events.is_empty());

        // Capture emitted events
        let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
            .with_contract_address(test_address())
            .build();

        // Assert that each original event was emitted as expected
        for event in evm_events {
            let starknet_event = EventIntoStarknetEvent::into(
                event
            ); // Convert to StarkNet event format
            contract_events.assert_emitted(@starknet_event);
        };
    }
}
// #[test]
// #[ignore]
//TODO(starknet-foundry): it's impossible to deploy an un-declared class, nor is it possible to
//mock_deploy.
// fn test_exec_sstore_finalized() { // // Given
// setup_test_environment();
// let mut vm = VMBuilderTrait::new_with_presets().build();
// let evm_address = vm.message().target.evm;
// let starknet_address = compute_starknet_address(
//     test_address(), evm_address, uninitialized_account()
// );
// let account = Account {
//     address: Address { evm: evm_address, starknet: starknet_address },
//     code: [].span(),
//     nonce: 1,
//     balance: 0,
//     selfdestruct: false,
//     is_created: false,
// };
// let key: u256 = 0x100000000000000000000000000000001;
// let value: u256 = 0xABDE1E11A5;
// vm.stack.push(value).expect('push failed');
// vm.stack.push(key).expect('push failed');

// // When

// vm.exec_sstore().expect('exec_sstore failed');
// starknet_backend::commit(ref vm.env.state).expect('commit storage failed');

// // Then
// assert(fetch_original_storage(@account, key) == value, 'wrong committed value')
// }
// }


