// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.stop_and_arithmetic_operations import StopAndArithmeticOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_add__should_add_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_add(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 5;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_mul__should_mul_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_mul(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 6;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_sub__should_sub_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_sub(ctx);

    // Then
    assert result.gas_used = 3;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_div__should_div_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_div(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_sdiv__should_signed_div_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_sdiv(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_mod__should_mod_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_mod(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_smod__should_smod_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_smod(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    let (stack, index1) = Stack.peek(stack, 1);
    assert index1.low = 1;
    assert index1.high = 0;
    return ();
}

@external
func test__exec_addmod__should_add_0_and_1_and_div_rem_by_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(2, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_addmod(ctx);

    // Then
    assert result.gas_used = 8;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_mulmod__should_mul_0_and_1_and_div_rem_by_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_mulmod(ctx);

    // Then
    assert result.gas_used = 8;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_exp__should_exp_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_exp(ctx);

    // Then
    assert result.gas_used = 10;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 9;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_signextend__should_signextend_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack = Stack.init();

    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_0 = new Uint256(3, 0);

    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = StopAndArithmeticOperations.exec_signextend(ctx);

    // Then
    assert result.gas_used = 5;
    assert result.stack.size = 2;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 2;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_stop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    assert ctx.stopped = FALSE;

    let stopped_ctx = StopAndArithmeticOperations.exec_stop(ctx);

    assert stopped_ctx.stopped = TRUE;
    assert stopped_ctx.return_data_len = 0;

    return ();
}
