use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::KakarotCore;
use contracts::kakarot_core::eth_rpc::IEthRPC;
use core::num::traits::Bounded;
use core::ops::SnapshotDeref;
use core::starknet::storage::{StoragePointerReadAccess};
use core::starknet::{get_caller_address};
use crate::gas;
use starknet::storage::StorageTrait;
use utils::eth_transaction::check_gas_fee;
use utils::eth_transaction::transaction::{Transaction, TransactionTrait};

/// Validates the ethereum transaction by checking adherence to Ethereum rules regarding
/// Gas logic, nonce, chainId and required balance.
///
/// # Returns
///
/// * The intrinsic gas cost of the transaction
pub fn validate_eth_tx(kakarot_state: @KakarotCore::ContractState, tx: Transaction) -> u64 {
    let kakarot_storage = kakarot_state.snapshot_deref().storage();
    // Validate transaction

    // Validate chain_id for post eip155
    let tx_chain_id = tx.chain_id();
    let kakarot_chain_id: u64 = kakarot_state.eth_chain_id();
    if (tx_chain_id.is_some()) {
        assert(tx_chain_id.unwrap() == kakarot_chain_id, 'Invalid chain id');
    }

    // Validate nonce
    let starknet_caller_address = get_caller_address();
    let account = IAccountDispatcher { contract_address: starknet_caller_address };
    let account_nonce = account.get_nonce();
    assert(account_nonce == tx.nonce(), 'Invalid nonce');
    assert(account_nonce != Bounded::<u64>::MAX, 'Nonce overflow');

    // Validate gas
    let gas_limit = tx.gas_limit();
    assert(gas_limit <= kakarot_storage.Kakarot_block_gas_limit.read(), 'Tx gas > Block gas');
    let block_base_fee = kakarot_storage.Kakarot_base_fee.read();
    let gas_fee_check = check_gas_fee(
        tx.max_fee_per_gas(), tx.max_priority_fee_per_gas(), block_base_fee.into()
    );
    assert!(gas_fee_check.is_ok(), "{:?}", gas_fee_check.unwrap_err());

    // Intrinsic Gas
    let intrinsic_gas = gas::calculate_intrinsic_gas_cost(@tx);
    assert(gas_limit >= intrinsic_gas, 'Intrinsic gas > gas limit');

    // Validate balance
    let balance = kakarot_state.eth_get_balance(account.get_evm_address());
    let max_gas_fee = tx.gas_limit().into() * tx.max_fee_per_gas();
    let tx_cost = tx.value() + max_gas_fee.into();
    assert(tx_cost <= balance, 'Not enough ETH');
    intrinsic_gas
}

#[cfg(test)]
mod tests {
    use contracts::kakarot_core::KakarotCore;
    use core::num::traits::Bounded;
    use core::ops::SnapshotDeref;
    use core::starknet::storage::{StorageTrait, StoragePathEntry};
    use core::starknet::{EthAddress, ContractAddress};
    use evm::gas;
    use snforge_std::cheatcodes::storage::{store_felt252};
    use snforge_std::{
        start_mock_call, test_address, start_cheat_chain_id_global, store,
        start_cheat_caller_address, mock_call
    };
    use super::validate_eth_tx;
    use utils::constants::BLOCK_GAS_LIMIT;
    use utils::eth_transaction::common::TxKind;
    use utils::eth_transaction::eip1559::TxEip1559;
    use utils::eth_transaction::legacy::TxLegacy;
    use utils::eth_transaction::transaction::Transaction;

    fn set_up() -> (KakarotCore::ContractState, ContractAddress) {
        // Define the addresses used in the tests, whose calls will be mocked
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        let kakarot_storage = kakarot_state.snapshot_deref().storage();
        let kakarot_address = test_address();
        let account_evm_address: EthAddress = 'account_evm_address'.try_into().unwrap();
        let account_starknet_address = 'account_starknet_address'.try_into().unwrap();
        let native_token_address = 'native_token_address'.try_into().unwrap();

        // Set up the environment
        start_cheat_chain_id_global(1);
        let base_fee_storage = kakarot_storage.Kakarot_base_fee.__base_address__;
        let block_gas_limit_storage = kakarot_storage.Kakarot_block_gas_limit.__base_address__;
        let native_token_storage_address = kakarot_storage
            .Kakarot_native_token_address
            .__base_address__;
        store_felt252(kakarot_address, base_fee_storage, 1_000_000_000); // 1 Gwei
        store_felt252(kakarot_address, block_gas_limit_storage, BLOCK_GAS_LIMIT.into());
        store_felt252(kakarot_address, native_token_storage_address, native_token_address.into());
        let map_entry_address = kakarot_storage
            .Kakarot_evm_to_starknet_address
            .entry(account_evm_address)
            .deref()
            .__storage_pointer_address__;
        store(
            kakarot_address,
            map_entry_address.into(),
            array![account_starknet_address.into()].span()
        );

        // Mock the calls to the account contract and the native token contract
        start_cheat_caller_address(kakarot_address, account_starknet_address);
        start_mock_call(account_starknet_address, selector!("get_nonce"), 0);
        start_mock_call(
            account_starknet_address, selector!("get_evm_address"), account_evm_address
        );
        start_mock_call(
            native_token_address, selector!("balanceOf"), Bounded::<u256>::MAX
        ); // Min to pay for gas + value

        (kakarot_state, native_token_address)
    }

    #[test]
    fn test_validate_eth_tx_typical_case() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: 21000, // Standard gas limit for a simple transfer
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        let intrinsic_gas = validate_eth_tx(@kakarot_state, tx);

        assert_eq!(intrinsic_gas, 21000); // Standard intrinsic gas for a simple transfer
    }

    #[test]
    #[should_panic(expected: ('Invalid chain id',))]
    fn test_validate_eth_tx_invalid_chain_id() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 600, // wrong chain_id
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: 21000, // Standard gas limit for a simple transfer
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        validate_eth_tx(@kakarot_state, tx);
    }

    #[test]
    #[should_panic(expected: ('Invalid nonce',))]
    fn test_validate_eth_tx_invalid_nonce() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 600, //Invalid nonce
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: 21000, // Standard gas limit for a simple transfer
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        validate_eth_tx(@kakarot_state, tx);
    }

    #[test]
    #[should_panic(expected: ('Tx gas > Block gas',))]
    fn test_validate_eth_tx_gas_limit_exceeds_block_gas_limit() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: BLOCK_GAS_LIMIT + 1, // Gas limit greater than block gas limit
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        validate_eth_tx(@kakarot_state, tx);
    }

    #[test]
    #[should_panic(expected: ('Intrinsic gas > gas limit',))]
    fn test_validate_eth_tx_intrinsic_gas_exceeds_gas_limit() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let mut tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: 0,
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        validate_eth_tx(@kakarot_state, tx);
    }

    #[test]
    #[should_panic(expected: ('Not enough ETH',))]
    fn test_validate_eth_tx_insufficient_balance() {
        // Setup the environment
        let (kakarot_state, native_token_address) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: 21000, // Standard gas limit for a simple transfer
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        start_mock_call(native_token_address, selector!("balanceOf"), Bounded::<u256>::MIN);

        // Test that the function performs validation and assert expected results
        validate_eth_tx(@kakarot_state, tx);
    }

    #[test]
    fn test_validate_eth_tx_max_gas_limit() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Eip1559(
            TxEip1559 {
                chain_id: 1, // Should match the chain_id in the environment
                nonce: 0,
                max_priority_fee_per_gas: 1_000_000_000, // 1 Gwei
                max_fee_per_gas: 2_000_000_000, // 2 Gwei
                gas_limit: BLOCK_GAS_LIMIT, // Gas limit = Max block gas limit
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // 1 ETH
                input: array![].span(),
                access_list: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        let intrinsic_gas = validate_eth_tx(@kakarot_state, tx);
        assert_eq!(intrinsic_gas, 21000); // Standard intrinsic gas for a simple transfer
    }

    #[test]
    fn test_validate_eth_tx_pre_eip155() {
        // Setup the environment
        let (kakarot_state, _) = set_up();

        // Create a transaction object for the test
        let tx = Transaction::Legacy(
            TxLegacy {
                chain_id: Option::None,
                nonce: 0,
                gas_price: 120000000000000000000000000,
                gas_limit: 21000,
                to: TxKind::Call(0x1234567890123456789012345678901234567890.try_into().unwrap()),
                value: 1000000000000000000_u256, // Standard gas limit for a simple transfer
                input: array![].span(),
            }
        );

        // Test that the function performs validation and assert expected results
        let intrinsic_gas = validate_eth_tx(@kakarot_state, tx);

        assert_eq!(intrinsic_gas, 21000); // Standard intrinsic gas for a simple transfer
    }
}
