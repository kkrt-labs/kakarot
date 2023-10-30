// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.comparison_operations import ComparisonOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_lt__should_pop_0_and_1_and_push_0__when_0_not_lt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_lt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_lt__should_pop_0_and_1_and_push_1__when_0_lt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_lt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_gt__should_pop_0_and_1_and_push_0__when_0_not_gt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_gt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_gt__should_pop_0_and_1_and_push_1__when_0_gt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_gt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_slt__should_pop_0_and_1_and_push_0__when_0_not_slt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_slt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_slt__should_pop_0_and_1_and_push_1__when_0_slt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_slt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_sgt__should_pop_0_and_1_and_push_0__when_0_not_sgt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_sgt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_sgt__should_pop_0_and_1_and_push_1__when_0_sgt_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_sgt(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_eq__should_pop_0_and_1_and_push_0__when_0_not_eq_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_eq(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_eq__should_pop_0_and_1_and_push_1__when_0_eq_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_eq(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_iszero__should_pop_0_and_push_0__when_0_is_not_zero{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_iszero(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_iszero__should_pop_0_and_push_1__when_0_is_zero{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_iszero(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_and__should_pop_0_and_1_and_push_0__when_0_and_1_are_not_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_and(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_and__should_pop_0_and_1_and_push_1__when_0_and_1_are_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_and(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_and__should_pop_0_and_1_and_push_0x89__when_0_is_0xC9_and_1_is_0xBD{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(0xbd, 0);
    tempvar item_1 = new Uint256(0xc9, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_and(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0x89;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_or__should_pop_0_and_1_and_push_0__when_0_or_1_are_not_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0, 0);
    tempvar item_1 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_or(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_or__should_pop_0_and_1_and_push_1__when_0_or_1_are_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_or(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_or__should_pop_0_and_1_and_push_0xCD__when_0_is_0x89_and_1_is_0xC5{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0xc5, 0);
    tempvar item_1 = new Uint256(0x89, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_or(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0xcd;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_xor__should_pop_0_and_1_and_push_0__when_0_and_1_are_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_xor(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_xor__should_pop_0_and_1_and_push_0__when_0_and_1_are_not_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0, 0);
    tempvar item_1 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_xor(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_xor__should_pop_0_and_1_and_push_1__when_0_is_true_and_1_is_not_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0, 0);
    tempvar item_1 = new Uint256(1, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_xor(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_xor__should_pop_0_and_1_and_push_1__when_0_is_not_true_and_1_is_true{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_xor(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_xor__should_pop_0_and_1_and_push_0x64__when_0_is_0xB9_and_1_is_0xDD{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    tempvar item_0 = new Uint256(0xdd, 0);
    tempvar item_1 = new Uint256(0xb9, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_xor(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0x64;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_byte__should_pop_0_and_1_and_push_0__when_0_is_less_than_16_bytes_and_1_is_23{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(23, 0);
    tempvar item_1 = new Uint256(0xFFEEDDCCBBAA998877665544332211, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_byte(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0x99;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_byte__should_pop_0_and_1_and_push_0__when_0_is_larger_than_16_bytes_and_1_is_8{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(8, 0);
    tempvar item_1 = new Uint256(0, 0x123456789ABCDEF0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_byte(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0x12;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_shl__should_pop_0_and_1_and_push_left_shift{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(4, 0);
    tempvar item_1 = new Uint256(2, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_shl(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 32;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_shr__should_pop_0_and_1_and_push_right_shift{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(4, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_shr(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_sar__should_pop_0_and_1_and_push_shr{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();

    tempvar item_0 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(4, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = ComparisonOperations.exec_sar(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}
