// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// Local dependencies
from kakarot.contract_factory import EvmContractFactory
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(owner: felt, native_token_address_: felt, evm_contract_hash: felt) {
    EvmContractFactory.init(evm_contract_hash);
    return Kakarot.constructor(owner, native_token_address_);
}

@external
func deploy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    bytes_len: felt, bytes: felt*
) -> (evm_contract_address: felt) {
    let evm_contract_address = EvmContractFactory.deploy_contract(bytes_len, bytes);
    return (evm_contract_address,);
}

@external
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(code_len: felt, code: felt*, calldata_len: felt, calldata: felt*) -> (
    stack_len: felt, stack: Uint256*, memory_len: felt, memory: felt*, gas_used: felt
) {
    alloc_locals;
    let context = Kakarot.execute(code=code, code_len=code_len, calldata=calldata);
    let len = Stack.len(context.stack);
    return (
        stack_len=len,
        stack=context.stack.elements,
        memory_len=context.memory.bytes_len,
        memory=context.memory.bytes,
        gas_used=context.gas_used,
    );
}

@external
func set_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    registry_address_: felt
) {
    return Kakarot.set_account_registry(registry_address_);
}

@external
func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt
) {
    return Kakarot.set_native_token(native_token_address_);
}
