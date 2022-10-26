// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
// Local dependencies
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(owner: felt) {
    return Kakarot.constructor(owner);
}

@external
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(code_len: felt, code: felt*, calldata_len: felt, calldata: felt*) -> (
    top_stack: Uint256, memory_len: felt, memory: felt*
) {
    alloc_locals;
    let context = Kakarot.execute(code=code, code_len=code_len, calldata=calldata);
    let len = Stack.len(context.stack);
    if (len == 0) {
        tempvar top_stack = Uint256(0, 0);
    } else {
        tempvar top_stack = context.stack.elements[len - 1];
    }
    return (top_stack=top_stack, memory_len=context.memory.bytes_len, memory=context.memory.bytes);
}
