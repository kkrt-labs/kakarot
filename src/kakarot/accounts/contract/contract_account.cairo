// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.accounts.contract.library import ContractAccount

// @title EVM smart contract account representation.
// @author @abdelhamidbakhta

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, code_len: felt, code: felt*) {
    return ContractAccount.constructor(kakarot_address, code_len, code);
}

// @notice Store the bytecode of the contract.
// @param code: The bytecode of the contract.
// @param code_len: The length of the bytecode.
@external
func store_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(code_len: felt, code: felt*) {
    return ContractAccount.store_code(code_len, code);
}

// @notice This function is used to get the code of the smart contract.
// @return The code of the smart contract.
@view
func code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (code_len: felt, code: felt*) {
    return ContractAccount.code();
}

// @notice Store a key-value pair
// @param code: The bytecode of the contract.
// @param code_len: The length of the bytecode.
@external
func write_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256, value: Uint256) {
    return ContractAccount.write_state(key, value);
}

// @notice This function is used to get the code of the smart contract.
// @return The code of the smart contract.
@view
func state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256) -> (value: Uint256) {
    return ContractAccount.read_state(key);
}
