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

// @notice This function is used to get the bytecode of the smart contract.
// @return The bytecode of the smart contract.
@view
func code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (code_len: felt, code: felt*) {
    return ContractAccount.code();
}

// @notice write to the contract state
// @dev write a value at a specific storage key
// @param key The key at which to write the storage value
// @param value The value to be stored 
@external
func write_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256, value: Uint256) {
    return ContractAccount.write_state(key, value);
}

// @notice read the contract state
// @dev read a storage value from the contract given a specific storage key
// @param key The key at which to fetch the storage value
// @return The value which was stored at the given key value
@view
func state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256) -> (value: Uint256) {
    return ContractAccount.read_state(key);
}
