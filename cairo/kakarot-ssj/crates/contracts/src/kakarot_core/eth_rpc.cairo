use core::num::traits::Zero;
use core::starknet::get_tx_info;
use core::starknet::{EthAddress, get_caller_address, ContractAddress};
use crate::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::kakarot_core::interface::IKakarotCore;
use crate::kakarot_core::kakarot::{KakarotCore, KakarotCore::{KakarotCoreState}};
use evm::backend::starknet_backend;
use evm::backend::validation::validate_eth_tx;
use evm::model::account::AccountTrait;
use evm::model::{TransactionResult, Address};
use evm::{EVMTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::MAX_SAFE_CHAIN_ID;
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};

#[starknet::interface]
pub trait IEthRPC<T> {
    /// Returns the balance of the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the balance from
    ///
    /// # Returns
    ///
    /// The balance of the address as a u256
    fn eth_get_balance(self: @T, address: EthAddress) -> u256;

    /// Returns the number of transactions sent from the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the transaction count from
    ///
    /// # Returns
    ///
    /// The transaction count of the address as a u64
    fn eth_get_transaction_count(self: @T, address: EthAddress) -> u64;

    /// Returns the current chain ID.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Returns
    ///
    /// The chain ID as a u64
    fn eth_chain_id(self: @T) -> u64;

    /// Executes a new message call immediately without creating a transaction on the block chain.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_call(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);

    /// Generates and returns an estimate of how much gas is necessary to allow the transaction to
    /// complete.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The estimated gas as a u64
    fn eth_estimate_gas(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);


    /// Executes an unsigned transaction.
    ///
    /// This is a modified version of the eth_sendRawTransaction function.
    /// Signature validation should be done before calling this function.
    ///
    /// # Arguments
    ///
    /// * `tx_data` - The unsigned transaction data as a Span<u8>
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_send_raw_unsigned_tx(ref self: T, tx_data: Span<u8>) -> (bool, Span<u8>, u64);
}


#[starknet::embeddable]
pub impl EthRPC<
    TContractState, impl KakarotState: KakarotCoreState<TContractState>, +Drop<TContractState>
> of IEthRPC<TContractState> {
    fn eth_get_balance(self: @TContractState, address: EthAddress) -> u256 {
        let kakarot_state = KakarotState::get_state();
        let starknet_address = kakarot_state.get_starknet_address(address);
        let native_token_address = kakarot_state.get_native_token();
        let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
        native_token.balanceOf(starknet_address)
    }

    fn eth_get_transaction_count(self: @TContractState, address: EthAddress) -> u64 {
        let kakarot_state = KakarotState::get_state();
        let starknet_address = kakarot_state.get_starknet_address(address);
        let account = IAccountDispatcher { contract_address: starknet_address };
        let nonce = account.get_nonce();
        nonce
    }

    fn eth_chain_id(self: @TContractState) -> u64 {
        let tx_info = get_tx_info().unbox();
        let tx_chain_id: u64 = tx_info.chain_id.try_into().unwrap();
        tx_chain_id % MAX_SAFE_CHAIN_ID.try_into().unwrap()
    }

    fn eth_call(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        if !is_view(@kakarot_state) {
            core::panic_with_felt252('fn must be called, not invoked');
        };

        let origin = Address { evm: origin, starknet: kakarot_state.get_starknet_address(origin) };

        let TransactionResult { success, return_data, gas_used, state: _state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, 0
        );

        (success, return_data, gas_used)
    }

    fn eth_estimate_gas(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }

    //TODO: we can't really unit-test this with foundry because we can't generate the RLP-encoding
    //in Cairo Find another way - perhaps test-data gen with python?
    fn eth_send_raw_unsigned_tx(
        ref self: TContractState, mut tx_data: Span<u8>
    ) -> (bool, Span<u8>, u64) {
        let tx = TransactionTrait::decode_enveloped(ref tx_data).expect('EOA: could not decode tx');
        EthRPCInternal::eth_send_transaction(ref self, tx)
    }
}

trait EthRPCInternal<T> {
    /// Executes a transaction and possibly modifies the state.
    ///
    /// This function implements the `eth_sendTransaction` method as described in the Ethereum
    /// JSON-RPC specification.
    /// The nonce is taken from the corresponding account contract.
    ///
    /// # Arguments
    ///
    /// * `tx` - A `Transaction` struct
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success (TRUE if the transaction succeeded, FALSE otherwise)
    /// * The return data as a `Span<u8>`
    /// * The amount of gas used by the transaction as a `u64`
    fn eth_send_transaction(ref self: T, tx: Transaction) -> (bool, Span<u8>, u64);
}

impl EthRPCInternalImpl<
    TContractState, impl KakarotState: KakarotCoreState<TContractState>, +Drop<TContractState>
> of EthRPCInternal<TContractState> {
    fn eth_send_transaction(ref self: TContractState, tx: Transaction) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        let intrinsic_gas = validate_eth_tx(@kakarot_state, tx);

        let starknet_caller_address = get_caller_address();
        // panics if the caller is a spoofer of an EVM address.
        //TODO: e2e test this! :) Send a transaction from an account that is not Kakarot's account
        //(e.g. deploy an account but not from Kakarot)
        let origin_evm_address = safe_get_evm_address(@self, starknet_caller_address);
        let origin = Address { evm: origin_evm_address, starknet: starknet_caller_address };

        let TransactionResult { success, return_data, gas_used, mut state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, intrinsic_gas
        );
        starknet_backend::commit(ref state).expect('Committing state failed');
        (success, return_data, gas_used)
    }
}


/// Returns the EVM address associated with a Starknet account deployed by Kakarot.
///
/// This function prevents cases where a Starknet account has an entrypoint `get_evm_address()`
/// but isn't part of the Kakarot system. It also mitigates re-entrancy risk with the Cairo Interop
/// module.
///
/// # Arguments
///
/// * `starknet_address` - The Starknet address of the account
///
/// # Returns
///
/// * `EthAddress` - The associated EVM address
///
/// # Panics
///
/// Panics if the declared corresponding EVM address (retrieved with `get_evm_address`)
/// does not recompute into the actual caller address.
fn safe_get_evm_address<
    TContractState, impl KakarotState: KakarotCoreState<TContractState>, +Drop<TContractState>
>(
    self: @TContractState, starknet_address: ContractAddress
) -> EthAddress {
    let account = IAccountDispatcher { contract_address: starknet_address };
    let evm_address = account.get_evm_address();
    let safe_starknet_address = AccountTrait::get_starknet_address(evm_address);
    assert!(
        safe_starknet_address == starknet_address,
        "Kakarot: caller contract is not a Kakarot Account"
    );
    evm_address
}

fn is_view(self: @KakarotCore::ContractState) -> bool {
    let tx_info = get_tx_info().unbox();

    // If the account that originated the transaction is not zero, this means we
    // are in an invoke transaction instead of a call; therefore, `eth_call` is being
    // wrongly called For invoke transactions, `eth_send_transaction` must be used
    if !tx_info.account_contract_address.is_zero() {
        return false;
    }
    true
}

#[cfg(test)]
mod tests {
    use core::ops::DerefMut;
    use core::starknet::EthAddress;
    use core::starknet::storage::{StoragePathEntry, StoragePointerWriteAccess};
    use crate::kakarot_core::KakarotCore;
    use crate::kakarot_core::eth_rpc::IEthRPC;
    use crate::kakarot_core::interface::{IKakarotCore, IExtendedKakarotCoreDispatcherTrait};
    use crate::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
    use evm::test_utils::{sequencer_evm_address, evm_address, uninitialized_account};
    use snforge_std::{
        start_mock_call, start_cheat_chain_id_global, stop_cheat_chain_id_global, test_address
    };
    use super::safe_get_evm_address;
    use utils::constants::MAX_SAFE_CHAIN_ID;

    fn set_up() -> KakarotCore::ContractState {
        // Define the kakarot state to access contract functions
        let kakarot_state = KakarotCore::unsafe_new_contract_state();

        kakarot_state
    }

    fn tear_down() {
        stop_cheat_chain_id_global();
    }

    #[test]
    fn test_eth_get_transaction_count() {
        let kakarot_state = set_up();
        let starknet_address = kakarot_state.get_starknet_address(evm_address());
        start_mock_call::<u256>(starknet_address, selector!("get_nonce"), 1);
        assert_eq!(kakarot_state.eth_get_transaction_count(evm_address()), 1);
    }

    #[test]
    fn test_eth_get_balance() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        // Uninitialized accounts should return a zero balance
        assert_eq!(kakarot_core.eth_get_balance(evm_address()), 0);
        let sequencer_starknet_address = kakarot_core.get_starknet_address(sequencer_evm_address());
        // Fund an initialized account and make sure the balance is correct
        fund_account_with_native_token(sequencer_starknet_address, native_token, 0x1);
        assert_eq!(kakarot_core.eth_get_balance(sequencer_evm_address()), 0x1);
    }

    #[test]
    fn test_eth_chain_id_returns_input_when_less_than_max_safe_chain_id() {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let chain_id: u64 = MAX_SAFE_CHAIN_ID - 1;
        start_cheat_chain_id_global(chain_id.into());
        assert_eq!(
            kakarot_state.eth_chain_id(),
            chain_id,
            "Should return original chain ID when below MAX_SAFE_CHAIN_ID"
        );
        tear_down();
    }

    #[test]
    fn test_eth_chain_id_returns_modulo_when_greater_than_or_equal_to_max_safe_chain_id() {
        // Test with a value equal to MAX_SAFE_CHAIN_ID
        let kakarot_state = set_up();
        start_cheat_chain_id_global(MAX_SAFE_CHAIN_ID.into());
        assert_eq!(kakarot_state.eth_chain_id(), 0, "Should return 0 when chain ID is MAX_SAFE_CHAIN_ID");

        // Test with a value greater than MAX_SAFE_CHAIN_ID
        let chain_id: u64 = MAX_SAFE_CHAIN_ID + 53;
        start_cheat_chain_id_global(chain_id.into());
        assert_eq!(
            kakarot_state.eth_chain_id(), 53, "Should return correct value after modulo operation"
        );
        tear_down();
    }

    #[test]
    fn test_safe_get_evm_address_succeeds() {
        let kakarot_state = set_up();
        // no registry - returns the computed address
        let starknet_address = kakarot_state.get_starknet_address(evm_address());
        start_mock_call::<
            EthAddress
        >(starknet_address, selector!("get_evm_address"), evm_address());
        let safe_evm_address = safe_get_evm_address(@kakarot_state, starknet_address);
        assert_eq!(safe_evm_address, evm_address());
    }

    #[test]
    #[should_panic(expected: "Kakarot: caller contract is not a Kakarot Account")]
    fn test_safe_get_evm_address_panics_when_caller_is_not_kakarot_account() {
        let mut kakarot_state = set_up();
        let mut kakarot_storage = kakarot_state.deref_mut();

        // Calling get_evm_address() on a fake starknet account that will return `evm_address()`.
        // Then, when computing the deterministic starknet_address with get_starknet_address(), it
        // will return a different address.
        // This should fail.
        let fake_starknet_account = 'fake_account'.try_into().unwrap();
        start_mock_call::<
            EthAddress
        >(fake_starknet_account, selector!("get_evm_address"), evm_address());
        safe_get_evm_address(@kakarot_state, fake_starknet_account);
    }
}
