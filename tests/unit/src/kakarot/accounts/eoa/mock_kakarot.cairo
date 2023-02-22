// SPDX-License-Identifier: MIT
// @dev mock kakarot contract
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from kakarot.library import native_token_address
from kakarot.constants import account_proxy_class_hash
from kakarot.accounts.library import Accounts

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

// @dev mock function that returns inputs for execute_at_address
@external
func execute_at_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*) -> (
    address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*
) {
    return (address, value, gas_limit, calldata_len, calldata);
}

// @dev mock function that returns inputs for deploy_contract_account
@external
func deploy_contract_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*) -> (bytecode_len: felt, bytecode: felt*) {
    return (bytecode_len, bytecode);
}

// @dev mock function that returns the computed starknet address from an evm address
@external
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let (contract_address_) = Accounts.compute_starknet_address(evm_address);
    return (contract_address=contract_address_);
}
