use contracts::errors::KAKAROT_REENTRANCY;
use contracts::test_data::counter_evm_bytecode;
use contracts::test_utils::{
    setup_contracts_for_testing, deploy_contract_account, fund_account_with_native_token, deploy_eoa
};
use contracts::{IAccountDispatcher, IAccountDispatcherTrait};
use core::starknet::EthAddress;
use core::starknet::account::{Call};
use evm::test_utils::{ca_address, eoa_address};
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};

#[test]
fn test_ca_deploy() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let initial_bytecode = contract_account.bytecode();
    assert(initial_bytecode.is_empty(), 'bytecode should be empty');
    assert(contract_account.get_evm_address() == ca_address.evm, 'wrong ca evm address');
    assert(contract_account.get_nonce() == 1, 'wrong nonce');
}

#[test]
fn test_ca_bytecode() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let bytecode = counter_evm_bytecode();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), bytecode);
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let contract_bytecode = contract_account.bytecode();
    assert(contract_bytecode == bytecode, 'wrong contract bytecode');
}


#[test]
fn test_ca_get_nonce() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let initial_nonce = contract_account.get_nonce();
    assert(initial_nonce == 1, 'nonce should be 1');

    let expected_nonce = 100;
    start_cheat_caller_address(ca_address.starknet, kakarot_core.contract_address);
    contract_account.set_nonce(expected_nonce);
    stop_cheat_caller_address(ca_address.starknet);

    let nonce = contract_account.get_nonce();

    assert(nonce == expected_nonce, 'wrong contract nonce');
}

#[test]
fn test_get_evm_address() {
    let expected_address: EthAddress = eoa_address();
    let (_, kakarot_core) = setup_contracts_for_testing();

    let eoa_contract = deploy_eoa(kakarot_core, eoa_address());

    assert(eoa_contract.get_evm_address() == expected_address, 'wrong evm_address');
}


#[test]
fn test_ca_storage() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let storage_slot = 0x555;

    let initial_storage = contract_account.storage(storage_slot);
    assert(initial_storage == 0, 'value should be 0');

    let expected_storage = 0x444;
    start_cheat_caller_address(ca_address.starknet, kakarot_core.contract_address);
    contract_account.write_storage(storage_slot, expected_storage);
    stop_cheat_caller_address(ca_address.starknet);

    let storage = contract_account.storage(storage_slot);

    assert(storage == expected_storage, 'wrong contract storage');
}

#[test]
fn test_ca_external_starknet_call_native_token() {
    let (native_token, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };
    fund_account_with_native_token(ca_address.starknet, native_token, 0x1);

    let call = Call {
        to: native_token.contract_address,
        selector: selector!("balance_of"),
        calldata: array![ca_address.starknet.into()].span(),
    };
    start_cheat_caller_address(ca_address.starknet, kakarot_core.contract_address);
    let (success, data) = contract_account.execute_starknet_call(call);
    stop_cheat_caller_address(ca_address.starknet);

    assert(success, 'execute_starknet_call failed');
    assert(data.len() == 2, 'wrong return data length');
    let balance = native_token.balance_of(ca_address.starknet);
    assert((*data[0], *data[1]) == (balance.low.into(), balance.high.into()), 'wrong return data');
}

#[test]
fn test_ca_external_starknet_call_kakarot_get_starknet_address() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let call = Call {
        to: kakarot_core.contract_address, selector: selector!("get_starknet_address"), calldata: [
            ca_address.evm.into()
        ].span(),
    };
    start_cheat_caller_address(ca_address.starknet, kakarot_core.contract_address);
    let (success, data) = contract_account.execute_starknet_call(call);
    stop_cheat_caller_address(ca_address.starknet);

    assert(success, 'execute_starknet_call failed');
    assert(data.len() == 1, 'wrong return data length');
    assert(*data[0] == ca_address.starknet.try_into().unwrap(), 'wrong return data');
}

#[test]
fn test_ca_external_starknet_call_cannot_call_kakarot_other_selector() {
    let (_, kakarot_core) = setup_contracts_for_testing();
    let ca_address = deploy_contract_account(kakarot_core, ca_address(), [].span());
    let contract_account = IAccountDispatcher { contract_address: ca_address.starknet };

    let call = Call {
        to: kakarot_core.contract_address,
        selector: selector!("get_native_token"),
        calldata: [].span(),
    };
    start_cheat_caller_address(ca_address.starknet, kakarot_core.contract_address);
    let (success, data) = contract_account.execute_starknet_call(call);
    stop_cheat_caller_address(ca_address.starknet);

    assert(!success, 'execute_starknet_call failed');
    assert(data.len() == 19, 'wrong return data length');
    assert(data == KAKAROT_REENTRANCY.span(), 'wrong return data');
}
