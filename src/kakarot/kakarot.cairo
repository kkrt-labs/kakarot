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
    top_stack: Uint256, top_memory: Uint256
) {
    let context = Kakarot.execute(code=code, code_len=code_len, calldata=calldata);
    let len = Stack.len(context.stack);
    tempvar top_stack = context.stack.elements[len - 1];
    let len = context.memory.bytes_len;
    if (len == 0) {
        return (top_stack=top_stack, top_memory=Uint256(0, 0),);
    } else {
        let top_memory = Memory.load(context.memory, len - 32);
        return (top_stack=top_stack, top_memory=top_memory,);
    }
}
