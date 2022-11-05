// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// Local dependencies
from kakarot.library import Kakarot, evm_contract_deployed
from kakarot.stack import Stack

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, native_token_address_: felt, evm_contract_class_hash: felt
) {
    return Kakarot.constructor(owner, native_token_address_, evm_contract_class_hash);
}

// value is given as first parameter of the execute() function
// because when added as the last parameter, calldata is altered and we didn't find why
@view
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(value: felt, code_len: felt, code: felt*, calldata_len: felt, calldata: felt*) -> (
    stack_len: felt, stack: Uint256*, memory_len: felt, memory: felt*, gas_used: felt
) {
    alloc_locals;
    let context = Kakarot.execute(code_len=code_len, code=code, calldata=calldata, value=value);
    let len = Stack.len(context.stack);
    return (
        stack_len=len,
        stack=context.stack.elements,
        memory_len=context.memory.bytes_len,
        memory=context.memory.bytes,
        gas_used=context.gas_used,
    );
}

// Create new function
@external
func execute_at_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt, calldata_len: felt, calldata: felt*, value: felt) -> (
    stack_len: felt, stack: Uint256*, memory_len: felt, memory: felt*
) {
    alloc_locals;

    let context = Kakarot.execute_at_address(address=address, calldata=calldata, value=value);
    let len = Stack.len(context.stack);
    return (
        stack_len=len,
        stack=context.stack.elements,
        memory_len=context.memory.bytes_len,
        memory=context.memory.bytes,
    );
}

@external
func set_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    registry_address_: felt
) {
    return Kakarot.set_account_registry(registry_address_);
}

@view
func get_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return Kakarot.get_account_registry();
}

@external
func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt
) {
    return Kakarot.set_native_token(native_token_address_);
}

// @notice deploy starknet contract
// @dev starknet contract will be mapped to an evm address that is also generated within this function
// @param bytes: the contract code
// @return evm address that is mapped to the actual contract address
@external
func deploy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    bytes_len: felt, bytes: felt*
) -> (evm_contract_address: felt, starknet_contract_address: felt) {
    let (evm_contract_address, starknet_contract_address) = Kakarot.deploy_contract(
        bytes_len, bytes
    );
    evm_contract_deployed.emit(
        evm_contract_address=evm_contract_address,
        starknet_contract_address=starknet_contract_address,
    );
    return (evm_contract_address, starknet_contract_address);
}
