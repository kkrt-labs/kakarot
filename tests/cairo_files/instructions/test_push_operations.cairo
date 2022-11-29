// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.push_operations import PushOperations
from tests.utils.utils import TestHelpers

@external
func test__exec_push1_should_add_1_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // we initialize the code with two entries of 0xFF and ensure push1 will only push the first one
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(2, 0xFF);
    let result = PushOperations.exec_push1(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFF);

    return ();
}

@external
func test__exec_push2_should_add_2_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(3, 0xFF);
    let result = PushOperations.exec_push2(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFF);

    return ();
}

@external
func test__exec_push3_should_add_3_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(4, 0xFF);
    let result = PushOperations.exec_push3(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFF);

    return ();
}

@external
func test__exec_push4_should_add_4_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(5, 0xFF);
    let result = PushOperations.exec_push4(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFF);

    return ();
}

@external
func test__exec_push5_should_add_5_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(6, 0xFF);
    let result = PushOperations.exec_push5(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFF);

    return ();
}

@external
func test__exec_push6_should_add_6_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(7, 0xFF);
    let result = PushOperations.exec_push6(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push7_should_add_7_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(8, 0xFF);
    let result = PushOperations.exec_push7(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push8_should_add_8_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(9, 0xFF);
    let result = PushOperations.exec_push8(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push9_should_add_9_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(10, 0xFF);
    let result = PushOperations.exec_push9(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push10_should_add_10_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(11, 0xFF);
    let result = PushOperations.exec_push10(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push11_should_add_11_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(12, 0xFF);
    let result = PushOperations.exec_push11(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push12_should_add_12_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(13, 0xFF);
    let result = PushOperations.exec_push12(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push13_should_add_13_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(14, 0xFF);
    let result = PushOperations.exec_push13(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push14_should_add_14_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(15, 0xFF);
    let result = PushOperations.exec_push14(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    return ();
}

@external
func test__exec_push15_should_add_15_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(16, 0xFF);
    let result = PushOperations.exec_push15(ctx);
    TestHelpers.assert_stack_last_element_contains(result.stack, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    return ();
}
