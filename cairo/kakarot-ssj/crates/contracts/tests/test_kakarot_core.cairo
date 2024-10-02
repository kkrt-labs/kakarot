use contracts::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use contracts::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
use contracts::kakarot_core::{KakarotCore};
use contracts::test_contracts::test_upgradeable::{
    IMockContractUpgradeableDispatcher, IMockContractUpgradeableDispatcherTrait
};
use contracts::test_data::{deploy_counter_calldata, counter_evm_bytecode};
use contracts::{test_utils as contract_utils,};
use core::num::traits::Zero;
use core::ops::SnapshotDeref;
use core::option::OptionTrait;
use core::starknet::storage::StoragePathEntry;
use core::starknet::{contract_address_const, ContractAddress, EthAddress, ClassHash};


use core::traits::TryInto;
use evm::test_utils::chain_id;
use evm::test_utils;
use snforge_std::{
    declare, DeclareResultTrait, start_cheat_caller_address, spy_events, EventSpyTrait,
    cheat_caller_address, CheatSpan, store
};
use snforge_utils::snforge_utils::{EventsFilterBuilderTrait, ContractEventsTrait};
use starknet::storage::StorageTrait;
use utils::eth_transaction::legacy::TxLegacy;
use utils::eth_transaction::transaction::Transaction;
use utils::helpers::{u256_to_bytes_array};
use utils::traits::eth_address::EthAddressExTrait;

#[test]
fn test_kakarot_core_owner() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_transfer_ownership() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    kakarot_core.transfer_ownership(test_utils::starknet_address());
    assert(kakarot_core.owner() == test_utils::starknet_address(), 'wrong owner')
}

#[test]
fn test_kakarot_core_renounce_ownership() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    assert(kakarot_core.owner() == test_utils::other_starknet_address(), 'wrong owner');
    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    kakarot_core.renounce_ownership();
    assert(kakarot_core.owner() == contract_address_const::<0x00>(), 'wrong owner')
}

#[test]
fn test_kakarot_core_chain_id() {
    contract_utils::setup_contracts_for_testing();

    assert(chain_id() == test_utils::chain_id(), 'wrong chain id');
}

#[test]
fn test_kakarot_core_set_native_token() {
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    assert(kakarot_core.get_native_token() == native_token.contract_address, 'wrong native_token');

    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    kakarot_core.set_native_token(contract_address_const::<0xdead>());
    assert(
        kakarot_core.get_native_token() == contract_address_const::<0xdead>(),
        'wrong new native_token'
    );
}

#[test]
fn test_kakarot_core_deploy_eoa() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let mut spy = spy_events();
    let eoa_starknet_address = kakarot_core
        .deploy_externally_owned_account(test_utils::evm_address());

    let expected = KakarotCore::Event::AccountDeployed(
        KakarotCore::AccountDeployed {
            evm_address: test_utils::evm_address(), starknet_address: eoa_starknet_address
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(kakarot_core.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
fn test_kakarot_core_eoa_mapping() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    assert(
        kakarot_core.address_registry(test_utils::evm_address()).is_zero(),
        'should be uninitialized'
    );

    let expected_eoa_starknet_address = kakarot_core
        .deploy_externally_owned_account(test_utils::evm_address());

    // When
    let address = kakarot_core.address_registry(test_utils::evm_address());

    // Then
    assert_eq!(address, expected_eoa_starknet_address);

    let another_sn_address: ContractAddress = 0xbeef.try_into().unwrap();

    // Set the address registry to the another_sn_address
    let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
    let map_entry_address = kakarot_state
        .snapshot_deref()
        .storage()
        .Kakarot_evm_to_starknet_address
        .entry(test_utils::evm_address())
        .deref()
        .__storage_pointer_address__;
    store(
        kakarot_core.contract_address, map_entry_address.into(), [another_sn_address.into()].span()
    );

    let address = kakarot_core.address_registry(test_utils::evm_address());
    assert_eq!(address, another_sn_address)
}

#[test]
fn test_kakarot_core_compute_starknet_address() {
    let evm_address = test_utils::evm_address();
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let expected_starknet_address = kakarot_core.deploy_externally_owned_account(evm_address);

    let actual_starknet_address = kakarot_core.compute_starknet_address(evm_address);
    assert_eq!(actual_starknet_address, expected_starknet_address);
}

#[test]
fn test_kakarot_core_upgrade_contract() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let class_hash: ClassHash = (*declare("MockContractUpgradeableV1")
        .unwrap()
        .contract_class()
        .class_hash);

    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    kakarot_core.upgrade(class_hash);

    let version = IMockContractUpgradeableDispatcher {
        contract_address: kakarot_core.contract_address
    }
        .version();
    assert(version == 1, 'version is not 1');
}

#[test]
fn test_eth_send_transaction_non_deploy_tx() {
    // Given
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
    contract_utils::fund_account_with_native_token(
        eoa, native_token, 0xfffffffffffffffffffffffffff
    );

    let counter_address = 'counter_contract'.try_into().unwrap();
    contract_utils::deploy_contract_account(kakarot_core, counter_address, counter_evm_bytecode());

    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;

    // Then
    // selector: function get()
    let data_get_tx = [0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 0 before doing inc
    let tx = contract_utils::call_transaction(
        chain_id(), Option::Some(counter_address), data_get_tx
    );
    let (_, return_data, _) = kakarot_core
        .eth_call(origin: evm_address, tx: Transaction::Legacy(tx));

    assert_eq!(return_data, u256_to_bytes_array(0).span());

    // selector: function inc()
    let data_increment_counter = [0x37, 0x13, 0x03, 0xc0].span();

    // When
    start_cheat_caller_address(kakarot_core.contract_address, eoa);

    let tx = TxLegacy {
        chain_id: Option::Some(chain_id()),
        nonce: 0,
        to: counter_address.into(),
        value,
        gas_price,
        gas_limit,
        input: data_increment_counter
    };

    let (success, _, _) = kakarot_core.eth_send_transaction(Transaction::Legacy(tx));
    assert!(success);

    // Then
    // selector: function get()
    let data_get_tx = [0x6d, 0x4c, 0xe6, 0x3c].span();

    // check counter value is 1
    let tx = contract_utils::call_transaction(
        chain_id(), Option::Some(counter_address), data_get_tx
    );
    let (_, return_data, _) = kakarot_core
        .eth_call(origin: evm_address, tx: Transaction::Legacy(tx));

    // Then
    assert_eq!(return_data, u256_to_bytes_array(1).span());
}

#[test]
fn test_eth_call() {
    // Given
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    kakarot_core.deploy_externally_owned_account(evm_address);

    let account = contract_utils::deploy_contract_account(
        kakarot_core, test_utils::other_evm_address(), counter_evm_bytecode()
    );
    let counter = IAccountDispatcher { contract_address: account.starknet };
    cheat_caller_address(
        counter.contract_address, kakarot_core.contract_address, CheatSpan::TargetCalls(1)
    );
    counter.write_storage(0, 1);

    let to = Option::Some(test_utils::other_evm_address());
    // selector: function get()
    let calldata = [0x6d, 0x4c, 0xe6, 0x3c].span();

    // When
    let tx = contract_utils::call_transaction(chain_id(), to, calldata);
    let (success, return_data, _) = kakarot_core
        .eth_call(origin: evm_address, tx: Transaction::Legacy(tx));

    // Then
    assert_eq!(success, true);
    assert_eq!(return_data, u256_to_bytes_array(1).span());
}


#[test]
fn test_eth_send_transaction_deploy_tx() {
    // Given
    let (native_token, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let evm_address = test_utils::evm_address();
    let eoa = kakarot_core.deploy_externally_owned_account(evm_address);
    contract_utils::fund_account_with_native_token(
        eoa, native_token, 0xfffffffffffffffffffffffffff
    );

    let gas_limit = test_utils::tx_gas_limit();
    let gas_price = test_utils::gas_price();
    let value = 0;

    // When
    // Set the contract address to the EOA address, so that the caller of the `eth_send_transaction`
    // is an eoa
    let tx = TxLegacy {
        chain_id: Option::Some(chain_id()),
        nonce: 0,
        to: Option::None.into(),
        value,
        gas_price,
        gas_limit,
        input: deploy_counter_calldata()
    };
    start_cheat_caller_address(kakarot_core.contract_address, eoa);
    let (_, deploy_result, _) = kakarot_core.eth_send_transaction(Transaction::Legacy(tx));

    // Then
    let expected_address: EthAddress = 0x19587b345dcadfe3120272bd0dbec24741891759
        .try_into()
        .unwrap();
    assert_eq!(deploy_result, expected_address.to_bytes().span());

    // Set back the contract address to Kakarot for the calculation of the deployed SN contract
    // address, where we use a kakarot internal functions and thus must "mock" its address.
    let computed_sn_addr = kakarot_core.compute_starknet_address(expected_address);
    let CA = IAccountDispatcher { contract_address: computed_sn_addr };
    let bytecode = CA.bytecode();
    assert_eq!(bytecode, counter_evm_bytecode());

    // Check that the account was created and `get` returns 0.
    let input = [0x6d, 0x4c, 0xe6, 0x3c].span();

    // No need to set address back to eoa, as eth_call doesn't use the caller address.
    let tx = TxLegacy {
        chain_id: Option::Some(chain_id()),
        nonce: 0,
        to: expected_address.into(),
        value,
        gas_price,
        gas_limit,
        input
    };
    let (_, result, _) = kakarot_core.eth_call(origin: evm_address, tx: Transaction::Legacy(tx));
    // Then
    assert(result == u256_to_bytes_array(0).span(), 'wrong result');
}


#[test]
fn test_account_class_hash() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();
    let uninitialized_account_class_hash = declare("UninitializedAccount")
        .unwrap()
        .contract_class()
        .class_hash;

    let class_hash = kakarot_core.uninitialized_account_class_hash();

    assert(class_hash == *uninitialized_account_class_hash, 'wrong class hash');

    let new_class_hash: ClassHash = (*declare("MockContractUpgradeableV1")
        .unwrap()
        .contract_class()
        .class_hash);
    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    let mut spy = spy_events();
    kakarot_core.set_account_class_hash(new_class_hash);

    assert(kakarot_core.uninitialized_account_class_hash() == new_class_hash, 'wrong class hash');
    let expected = KakarotCore::Event::AccountClassHashChange(
        KakarotCore::AccountClassHashChange {
            old_class_hash: class_hash, new_class_hash: new_class_hash
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(kakarot_core.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
fn test_account_contract_class_hash() {
    let (_, kakarot_core) = contract_utils::setup_contracts_for_testing();

    let account_contract_class_hash = (*declare("AccountContract")
        .unwrap()
        .contract_class()
        .class_hash);
    let class_hash = kakarot_core.get_account_contract_class_hash();

    assert(class_hash == account_contract_class_hash, 'wrong class hash');

    let new_class_hash: ClassHash = (*declare("MockContractUpgradeableV1")
        .unwrap()
        .contract_class()
        .class_hash);
    start_cheat_caller_address(kakarot_core.contract_address, test_utils::other_starknet_address());
    let mut spy = spy_events();
    kakarot_core.set_account_contract_class_hash(new_class_hash);
    assert(kakarot_core.get_account_contract_class_hash() == new_class_hash, 'wrong class hash');

    let expected = KakarotCore::Event::EOAClassHashChange(
        KakarotCore::EOAClassHashChange {
            old_class_hash: class_hash, new_class_hash: new_class_hash
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(kakarot_core.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}
