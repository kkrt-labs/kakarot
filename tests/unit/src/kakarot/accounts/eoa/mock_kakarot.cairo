// SPDX-License-Identifier: MIT
// @dev mock kakarot contract
%lang starknet

from openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

@storage_var
func native_token_address() -> (res: felt) {
}

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt
) {
    native_token_address.write(native_token_address_);
    return ();
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

// @dev mock_kakarot sends eth from one address to another one
// @param from_address address to send eth from
// @param to_address address to send eth to
// @param value amount of eth to send
@external
func transfer_from_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, to_address: felt, value: Uint256
) {
    let (native_token_address_) = native_token_address.read();
    IERC20.transferFrom(native_token_address_, from_address, to_address, value);
    return ();
}
