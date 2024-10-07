use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::dict::{Felt252Dict, Felt252DictTrait};
use core::num::traits::Zero;
use core::ops::SnapshotDeref;
use core::starknet::storage::{StoragePointerReadAccess, StoragePathEntry};
use core::starknet::{ContractAddress, EthAddress, get_contract_address};
use crate::backend::starknet_backend::fetch_balance;
use crate::model::Address;
use utils::constants::EMPTY_KECCAK;
use utils::helpers::compute_starknet_address;
use utils::traits::bytes::U8SpanExTrait;

#[derive(Drop)]
struct AccountBuilder {
    account: Account
}

#[generate_trait]
impl AccountBuilderImpl of AccountBuilderTrait {
    fn new(address: Address) -> AccountBuilder {
        AccountBuilder {
            account: Account {
                address: address,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                nonce: 0,
                balance: 0,
                selfdestruct: false,
                is_created: false
            }
        }
    }

    #[inline(always)]
    fn fetch_balance(mut self: AccountBuilder) -> AccountBuilder {
        self.account.balance = fetch_balance(@self.account.address);
        self
    }

    #[inline(always)]
    fn fetch_nonce(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        self.account.nonce = account.get_nonce();
        self
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a
    /// Span<u8>.
    /// # Arguments
    /// * `self` - The address of the Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    #[inline(always)]
    fn fetch_bytecode(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        let bytecode = account.bytecode();
        self.account.code = bytecode;
        self
    }

    #[inline(always)]
    fn fetch_code_hash(mut self: AccountBuilder) -> AccountBuilder {
        let account = IAccountDispatcher { contract_address: self.account.address.starknet };
        self.account.code_hash = account.get_code_hash();
        self
    }

    #[inline(always)]
    fn build(self: AccountBuilder) -> Account {
        self.account
    }
}

#[derive(Copy, Drop, PartialEq, Debug)]
pub struct Account {
    pub address: Address,
    pub code: Span<u8>,
    pub code_hash: u256,
    pub nonce: u64,
    pub balance: u256,
    pub selfdestruct: bool,
    pub is_created: bool,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    fn get_starknet_address(evm_address: EthAddress) -> ContractAddress {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let kakarot_storage = kakarot_state.snapshot_deref();
        let existing_address = kakarot_storage
            .Kakarot_evm_to_starknet_address
            .entry(evm_address)
            .read();
        if existing_address.is_zero() {
            return compute_starknet_address(
                get_contract_address(),
                evm_address,
                kakarot_state.uninitialized_account_class_hash()
            );
        }
        existing_address
    }


    /// Fetches an account from Starknet
    /// An non-deployed account is just an empty account.
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise a new empty account.
    fn fetch_or_create(evm_address: EthAddress) -> Account {
        let maybe_acc = Self::fetch(evm_address);

        match maybe_acc {
            Option::Some(account) => account,
            Option::None => {
                let kakarot_state = KakarotCore::unsafe_new_contract_state();
                let starknet_address = kakarot_state.get_starknet_address(evm_address);
                // If no account exists at `address`, then we are trying to
                // access an undeployed account. We create an
                // empty account with the correct address, fetch the balance, and return it.
                AccountBuilderTrait::new(Address { starknet: starknet_address, evm: evm_address })
                    .fetch_balance()
                    .build()
            }
        }
    }

    /// Fetches an account from Starknet
    ///
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise `None`.
    fn fetch(evm_address: EthAddress) -> Option<Account> {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let starknet_address = kakarot_state.address_registry(evm_address);
        if starknet_address.is_zero() {
            return Option::None;
        }
        let address = Address { starknet: starknet_address, evm: evm_address };
        Option::Some(
            AccountBuilderTrait::new(address)
                .fetch_nonce()
                .fetch_bytecode()
                .fetch_balance()
                .fetch_code_hash()
                .build()
        )
    }


    /// Returns whether an account exists at the given address by checking
    /// whether it has code or a nonce.
    ///
    /// # Arguments
    ///
    /// * `account` - The instance of the account to check.
    ///
    /// # Returns
    ///
    /// `true` if an account exists at this address (has code or nonce), `false` otherwise.
    #[inline(always)]
    fn has_code_or_nonce(self: @Account) -> bool {
        return !(*self.code).is_empty() || *self.nonce != 0;
    }

    #[inline(always)]
    fn is_created(self: @Account) -> bool {
        *self.is_created
    }

    #[inline(always)]
    fn set_created(ref self: Account, is_created: bool) {
        self.is_created = is_created;
    }

    #[inline(always)]
    fn balance(self: @Account) -> u256 {
        *self.balance
    }

    #[inline(always)]
    fn set_balance(ref self: Account, value: u256) {
        self.balance = value;
    }

    #[inline(always)]
    fn address(self: @Account) -> Address {
        *self.address
    }

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        *self.address.evm
    }

    #[inline(always)]
    fn starknet_address(self: @Account) -> ContractAddress {
        *self.address.starknet
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    #[inline(always)]
    fn bytecode(self: @Account) -> Span<u8> {
        *self.code
    }

    #[inline(always)]
    fn code_hash(self: @Account) -> u256 {
        *self.code_hash
    }


    /// Sets the nonce of the Account
    /// # Arguments
    /// * `self` The Account to set the nonce on
    /// * `nonce` The new nonce
    #[inline(always)]
    fn set_nonce(ref self: Account, nonce: u64) {
        self.nonce = nonce;
    }

    #[inline(always)]
    fn nonce(self: @Account) -> u64 {
        *self.nonce
    }

    /// Sets the code of the Account
    /// Also sets the code hash to be synced with the code
    /// # Arguments
    /// * `self` The Account to set the code on
    /// * `code` The new code
    #[inline(always)]
    fn set_code(ref self: Account, code: Span<u8>) {
        self.code = code;
        if code.is_empty() {
            self.code_hash = EMPTY_KECCAK;
            return;
        }
        let hash = code.compute_keccak256_hash();
        self.code_hash = hash;
    }

    /// Registers an account for SELFDESTRUCT
    /// This will cause the account to be erased at the end of the transaction
    #[inline(always)]
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }

    /// Returns whether the account is registered for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    #[inline(always)]
    fn is_selfdestruct(self: @Account) -> bool {
        *self.selfdestruct
    }

    /// Initializes a dictionary of valid jump destinations in EVM bytecode.
    ///
    /// This function iterates over the bytecode from the current index 'i'.
    /// If the opcode at the current index is between 0x5f and 0x7f (PUSHN opcodes) (inclusive),
    /// it skips the next 'n_args' opcodes, where 'n_args' is the opcode minus 0x5f.
    /// If the opcode is 0x5b (JUMPDEST), it marks the current index as a valid jump destination.
    /// It continues by jumping back to the body flag until it has processed the entire bytecode.
    ///
    /// # Arguments
    /// * `bytecode` The bytecode to analyze
    ///
    /// # Returns
    /// A dictionary of valid jump destinations in the bytecode
    fn get_jumpdests(mut bytecode: Span<u8>) -> Felt252Dict<bool> {
        let mut jumpdests: Felt252Dict<bool> = Default::default();
        let mut i: usize = 0;
        while i < bytecode.len() {
            let opcode = *bytecode[i];
            // checking for PUSH opcode family
            if opcode >= 0x5f && opcode <= 0x7f {
                let n_args = opcode.into() - 0x5f;
                i += n_args + 1;
                continue;
            }

            if opcode == 0x5b {
                jumpdests.insert(i.into(), true);
            }

            i += 1;
        };
        jumpdests
    }
}

#[cfg(test)]
mod tests {
    mod test_has_code_or_nonce {
        use crate::model::account::{Account, AccountTrait, Address};
        use utils::constants::EMPTY_KECCAK;
        use utils::traits::bytes::U8SpanExTrait;

        #[test]
        fn test_should_return_false_when_empty() {
            let account = Account {
                address: Address { evm: 1.try_into().unwrap(), starknet: 1.try_into().unwrap() },
                nonce: 0,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(!account.has_code_or_nonce());
        }

        #[test]
        fn test_should_return_true_when_code() {
            let bytecode = [0x5b].span();
            let code_hash = bytecode.compute_keccak256_hash();
            let account = Account {
                address: Address { evm: 1.try_into().unwrap(), starknet: 1.try_into().unwrap() },
                nonce: 1,
                code: bytecode,
                code_hash: code_hash,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(account.has_code_or_nonce());
        }

        #[test]
        fn test_should_return_true_when_nonce() {
            let account = Account {
                address: Address { evm: 1.try_into().unwrap(), starknet: 1.try_into().unwrap() },
                nonce: 1,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(account.has_code_or_nonce());
        }
    }

    mod test_fetch {
        use crate::model::account::{Account, AccountTrait, Address};
        use crate::test_utils::{
            register_account, setup_test_environment, uninitialized_account, evm_address,
            native_token,
        };
        use snforge_std::{test_address, start_mock_call};
        use snforge_utils::snforge_utils::assert_called;
        use utils::constants::EMPTY_KECCAK;
        use utils::helpers::compute_starknet_address;

        #[test]
        fn test_should_fetch_data_from_storage_if_registered() {
            // Given
            setup_test_environment();
            let starknet_address = compute_starknet_address(
                test_address(), evm_address(), uninitialized_account()
            );
            register_account(evm_address(), starknet_address);

            let expected = Account {
                address: Address { evm: evm_address(), starknet: starknet_address },
                nonce: 1,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 100,
                selfdestruct: false,
                is_created: false,
            };

            // When
            start_mock_call::<u256>(native_token(), selector!("balanceOf"), 100);
            start_mock_call::<u64>(starknet_address, selector!("get_nonce"), 1);
            start_mock_call::<Span<u8>>(starknet_address, selector!("bytecode"), [].span());
            start_mock_call::<u256>(starknet_address, selector!("get_code_hash"), EMPTY_KECCAK);
            let account = AccountTrait::fetch(evm_address()).expect('Account should exist');

            // Then
            assert_eq!(account, expected);
            assert_called(starknet_address, selector!("get_nonce"));
            assert_called(starknet_address, selector!("bytecode"));
            assert_called(starknet_address, selector!("get_code_hash"));
            //TODO(starknet-foundry): we mocked the balanceOf call, but we should also check if it
            //was called with the right data
            assert_called(native_token(), selector!("balanceOf"));
        }

        #[test]
        fn test_should_return_none_if_not_registered() {
            // Given
            setup_test_environment();
            let _starknet_address = compute_starknet_address(
                test_address(), evm_address(), uninitialized_account()
            );

            assert!(AccountTrait::fetch(evm_address()).is_none());
        }
    }

    mod test_fetch_or_create {
        use crate::model::account::{Account, AccountTrait, Address};
        use crate::test_utils::{
            register_account, setup_test_environment, uninitialized_account, evm_address,
            native_token,
        };
        use snforge_std::{test_address, start_mock_call};
        use snforge_utils::snforge_utils::assert_called;
        use utils::constants::EMPTY_KECCAK;
        use utils::helpers::compute_starknet_address;

        #[test]
        fn test_should_fetch_data_from_storage_if_registered() {
            // Given
            setup_test_environment();
            let starknet_address = compute_starknet_address(
                test_address(), evm_address(), uninitialized_account()
            );
            register_account(evm_address(), starknet_address);

            let expected = Account {
                address: Address { evm: evm_address(), starknet: starknet_address },
                nonce: 1,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 100,
                selfdestruct: false,
                is_created: false,
            };

            // When
            start_mock_call::<u256>(native_token(), selector!("balanceOf"), 100);
            start_mock_call::<u64>(starknet_address, selector!("get_nonce"), 1);
            start_mock_call::<Span<u8>>(starknet_address, selector!("bytecode"), [].span());
            start_mock_call::<u256>(starknet_address, selector!("get_code_hash"), EMPTY_KECCAK);
            let account = AccountTrait::fetch_or_create(evm_address());

            // Then
            assert_eq!(account, expected);
            assert_called(starknet_address, selector!("get_nonce"));
            assert_called(starknet_address, selector!("bytecode"));
            assert_called(starknet_address, selector!("get_code_hash"));
            //TODO(starknet-foundry): we mocked the balanceOf call, but we should also check if it
            //was called with the right data
            assert_called(native_token(), selector!("balanceOf"));
        }

        #[test]
        fn test_should_create_new_account_with_starknet_balance_if_not_registered() {
            // Given
            setup_test_environment();
            let starknet_address = compute_starknet_address(
                test_address(), evm_address(), uninitialized_account()
            );

            let expected = Account {
                address: Address { evm: evm_address(), starknet: starknet_address },
                nonce: 0,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 50,
                selfdestruct: false,
                is_created: false,
            };

            // When
            start_mock_call::<u256>(native_token(), selector!("balanceOf"), 50);
            let account = AccountTrait::fetch_or_create(evm_address());

            // Then
            assert_eq!(account, expected);
            //TODO(starknet-foundry): we mocked the balanceOf call, but we should also check if it
            //was called with the right data
            assert_called(native_token(), selector!("balanceOf"));
        }
    }
    //TODO(starknet-foundry): add a test for get_jumpdests
}
