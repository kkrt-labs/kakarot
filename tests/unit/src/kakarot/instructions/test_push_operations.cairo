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
func test__exec_push_should_add_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i - 1, 0xFF);
    PushOperations.exec_push_i(ctx, i);
    
    return ();
} 

@external
func test__exec_push1_should_add_1_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // we initialize the code with two entries of 0xFF and ensure push1 will only push the first one
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(2, 0xFF);
    let result = PushOperations.exec_push1(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFF, 0));

    return ();
}

@external
func test__exec_push2_should_add_2_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(3, 0xFF);
    let result = PushOperations.exec_push2(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFFFF, 0));

    return ();
}

@external
func test__exec_push3_should_add_3_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(4, 0xFF);
    let result = PushOperations.exec_push3(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFFFFFF, 0));

    return ();
}

@external
func test__exec_push4_should_add_4_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(5, 0xFF);
    let result = PushOperations.exec_push4(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFFFFFFFF, 0));

    return ();
}

@external
func test__exec_push5_should_add_5_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(6, 0xFF);
    let result = PushOperations.exec_push5(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(result.stack, Uint256(0xFFFFFFFFFF, 0));

    return ();
}

@external
func test__exec_push6_should_add_6_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(7, 0xFF);
    let result = PushOperations.exec_push6(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push7_should_add_7_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(8, 0xFF);
    let result = PushOperations.exec_push7(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push8_should_add_8_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(9, 0xFF);
    let result = PushOperations.exec_push8(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push9_should_add_9_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(10, 0xFF);
    let result = PushOperations.exec_push9(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push10_should_add_10_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(11, 0xFF);
    let result = PushOperations.exec_push10(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push11_should_add_11_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(12, 0xFF);
    let result = PushOperations.exec_push11(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push12_should_add_12_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(13, 0xFF);
    let result = PushOperations.exec_push12(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push13_should_add_13_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(14, 0xFF);
    let result = PushOperations.exec_push13(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push14_should_add_14_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(15, 0xFF);
    let result = PushOperations.exec_push14(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push15_should_add_15_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(16, 0xFF);
    let result = PushOperations.exec_push15(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push16_should_add_16_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(17, 0xFF);
    let result = PushOperations.exec_push16(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}

@external
func test__exec_push17_should_add_17_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(18, 0xFF);
    let result = PushOperations.exec_push17(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFF)
    );

    return ();
}

@external
func test__exec_push18_should_add_18_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(19, 0xFF);
    let result = PushOperations.exec_push18(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFF)
    );

    return ();
}

@external
func test__exec_push19_should_add_19_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(20, 0xFF);
    let result = PushOperations.exec_push19(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFF)
    );

    return ();
}

@external
func test__exec_push20_should_add_20_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(21, 0xFF);
    let result = PushOperations.exec_push20(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push21_should_add_21_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(22, 0xFF);
    let result = PushOperations.exec_push21(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push22_should_add_22_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(23, 0xFF);
    let result = PushOperations.exec_push22(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push23_should_add_23_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(24, 0xFF);
    let result = PushOperations.exec_push23(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push24_should_add_24_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(25, 0xFF);
    let result = PushOperations.exec_push24(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push25_should_add_25_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(26, 0xFF);
    let result = PushOperations.exec_push25(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push26_should_add_26_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(27, 0xFF);
    let result = PushOperations.exec_push26(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push27_should_add_27_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(28, 0xFF);
    let result = PushOperations.exec_push27(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push28_should_add_28_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(29, 0xFF);
    let result = PushOperations.exec_push28(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push29_should_add_29_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(30, 0xFF);
    let result = PushOperations.exec_push29(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push30_should_add_30_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(31, 0xFF);
    let result = PushOperations.exec_push30(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push31_should_add_31_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(32, 0xFF);
    let result = PushOperations.exec_push31(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    return ();
}

@external
func test__exec_push32_should_add_32_byte_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(33, 0xFF);
    let result = PushOperations.exec_push32(ctx);
    TestHelpers.assert_stack_last_element_contains_uint256(
        result.stack,
        Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),
    );

    return ();
}
