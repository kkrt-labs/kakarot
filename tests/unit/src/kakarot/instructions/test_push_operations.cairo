// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.pow import pow

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.push_operations import PushOperations
from tests.unit.helpers.helpers import TestHelpers

@external
func test__exec_push_should_raise{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i - 1, 0xFF);
    PushOperations.exec_push_i(ctx, i);
    
    return ();
} 

@external
func test__exec_push_should_add_1_through_16_bytes_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i + 1, 0xFF);
    let result = PushOperations.exec_push_i(ctx, i);
    let (res) = pow(2, 8 * i); 
 
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(res - 0x01, 0));

    return ();
} 

@external
func test__exec_push_should_add_17_through_32_bytes_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i + 1, 0xFF);
    let result = PushOperations.exec_push_i(ctx, i);
    let (res) = pow(2, 8 * (i-16)); 

    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,  res - 0x01));

    return ();
} 
