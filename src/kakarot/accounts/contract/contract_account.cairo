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
}(kakarot_address: felt, bytecode_len: felt, bytecode: felt*) {
    return ContractAccount.constructor(kakarot_address, bytecode_len, bytecode);
}

// @notice Store the bytecode of the contract.
// @param bytecode: The bytecode of the contract.
// @param bytecode_len: The length of the bytecode.
@external
func write_bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, original_bytecode_len: felt) {
    return ContractAccount.write_bytecode(bytecode_len, bytecode, original_bytecode_len);
}

// @notice This function is used to get the bytecode of the smart contract.
// @return The bytecode of the smart contract.
@view
func bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (bytecode_len: felt, bytecode: felt*, original_bytecode_len: felt) {
    return ContractAccount.bytecode();
}

// @notice Store a key-value pair
// @param key: The bytes32 storage key.
// @param value: The bytes32 stored value.
@external
func write_storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256, value: Uint256) {
    return ContractAccount.write_storage(key, value);
}

// @notice Read a given storage key
// @return The stored value if the key exists, 0 otherwise.
@view
func storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(key: Uint256) -> (value: Uint256) {
    return ContractAccount.storage(key);
}

// @notice This function is used to initialize the smart contract.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ContractAccount.initialize();
}

// @notice This function checks if the account was initialized.
// @return is_initialized: 1 if the account has been initialized 0 otherwise.
@view
func is_initialized{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (is_initialized: felt) {
    return ContractAccount.is_initialized();
}
