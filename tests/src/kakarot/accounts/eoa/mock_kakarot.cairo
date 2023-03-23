// SPDX-License-Identifier: MIT
// @dev mock kakarot contract
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from kakarot.accounts.library import Accounts
from kakarot.constants import account_proxy_class_hash
from kakarot.library import native_token_address, Kakarot

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt, account_proxy_class_hash_: felt
) {
    native_token_address.write(native_token_address_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
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
    let (contract_address_) = Accounts.compute_starknet_address(evm_address);
    return (contract_address=contract_address_);
}

@view
func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*
) {
    alloc_locals;
    // Do the transfer
    Kakarot.transfer(to, value);

    // Mock only the execution part
    let (local return_data) = alloc();
    assert [return_data] = to;
    assert [return_data + 1] = gas_limit;
    assert [return_data + 2] = gas_price;
    assert [return_data + 3] = value;
    assert [return_data + 4] = data_len;
    memcpy(return_data + 5, data, data_len);
    return (data_len + 5, return_data);
}

@external
func eth_send_transaction{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*
) {
    alloc_locals;
    // Do the transfer
    Kakarot.transfer(to, value);

    // Mock only the execution part
    let (local return_data) = alloc();
    assert [return_data] = to;
    assert [return_data + 1] = gas_limit;
    assert [return_data + 2] = gas_price;
    assert [return_data + 3] = value;
    assert [return_data + 4] = data_len;
    memcpy(return_data + 5, data, data_len);
    return (data_len + 5, return_data);
}
