// SPDX-License-Identifier: MIT
// @dev mock kakarot contract
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address

from kakarot.account import Account
from kakarot.storages import account_proxy_class_hash, externally_owned_account_class_hash
from kakarot.library import native_token_address, Kakarot
from kakarot.interfaces.interfaces import IAccount

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt,
    account_proxy_class_hash_: felt,
    externally_owned_account_class_hash_: felt,
) {
    native_token_address.write(native_token_address_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    externally_owned_account_class_hash.write(externally_owned_account_class_hash_);
    return ();
}

// @dev mock function that returns the kakarot native token
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    let (native_token_address_) = native_token_address.read();
    return (native_token_address=native_token_address_);
}

// @dev mock function that returns the computed starknet address from an evm address
@external
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let (contract_address_) = Account.compute_starknet_address(evm_address);
    return (contract_address=contract_address_);
}

// @dev mock function that returns the registered starknet address from an evm address or 0
@view
func get_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (starknet_address: felt) {
    let starknet_address = Account.get_registered_starknet_address(evm_address);
    return (starknet_address=starknet_address);
}

// @notice Deploy a new externally owned account.
// @param evm_address The evm address that is mapped to the newly deployed starknet contract address.
// @return starknet_contract_address The newly deployed starknet contract address.
@external
func deploy_externally_owned_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(evm_address: felt) -> (starknet_contract_address: felt) {
    return Kakarot.deploy_externally_owned_account(evm_address);
}

@view
func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    to: felt,
    gas_limit: felt,
    gas_price: felt,
    value: felt,
    data_len: felt,
    data: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt) {
    alloc_locals;

    // Mock only the execution part
    let (local return_data) = alloc();
    assert [return_data] = origin;
    assert [return_data + 1] = to;
    assert [return_data + 2] = gas_limit;
    assert [return_data + 3] = gas_price;
    assert [return_data + 4] = value;
    assert [return_data + 5] = data_len;
    memcpy(return_data + 6, data, data_len);
    return (data_len + 6, return_data, 1);
}

@external
func eth_send_transaction{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*, success: felt
) {
    alloc_locals;
    let (local starknet_caller_address) = get_caller_address();
    let (local origin) = IAccount.get_evm_address(starknet_caller_address);
    return eth_call(origin, to, gas_limit, gas_price, value, data_len, data);
}
