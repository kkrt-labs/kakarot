// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_nn

// Local dependencies
from kakarot.instructions.exchange_operations import ExchangeOperations
from kakarot.model import model
from kakarot.stack import Stack
from tests.utils.utils import TestHelpers

@external
func test__exec_swap1__should_swap_1st_and_2nd{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {

    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(4, 0));
    let index3 = Stack.peek(stack, 3);
    assert index3 = Uint256(1, 0);
    let index2 = Stack.peek(stack, 2);
    assert index2 = Uint256(2, 0);
    let index1 = Stack.peek(stack, 1);
    assert index1 = Uint256(3, 0);
    let index0 = Stack.peek(stack, 0);
    assert index0 = Uint256(4, 0);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result =  ExchangeOperations.exec_swap1(ctx);

    // Then
    let index3 = Stack.peek(result.stack, 3);
    assert index3 = Uint256(1, 0);
    let index2 = Stack.peek(result.stack, 2);
    assert index2 = Uint256(2, 0);
    let index1 = Stack.peek(result.stack, 1);
    assert index1 = Uint256(4, 0);
    let index0 = Stack.peek(result.stack, 0);
    assert index0 = Uint256(3, 0);
    return ();

}

@external
func test__exec_swap2__should_swap_1st_and_3rd{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {

    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(4, 0));
    let index3 = Stack.peek(stack, 3);
    assert index3 = Uint256(1, 0);
    let index2 = Stack.peek(stack, 2);
    assert index2 = Uint256(2, 0);
    let index1 = Stack.peek(stack, 1);
    assert index1 = Uint256(3, 0);
    let index0 = Stack.peek(stack, 0);
    assert index0 = Uint256(4, 0);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result =  ExchangeOperations.exec_swap2(ctx);

    // Then
    let index3 = Stack.peek(result.stack, 3);
    assert index3 = Uint256(1, 0);
    let index2 = Stack.peek(result.stack, 2);
    assert index2 = Uint256(4, 0);
    let index1 = Stack.peek(result.stack, 1);
    assert index1 = Uint256(3, 0);
    let index0 = Stack.peek(result.stack, 0);
    assert index0 = Uint256(2, 0);
    return ();

}

@external
func test__exec_swap1__should_fail__when_index_1_is_underflow{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);


    // When & Then
    let result =  ExchangeOperations.exec_swap1(ctx);
    return ();
}

@external
func test__exec_swap2__should_fail__when_index_2_is_underflow{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When & Then
    let result =  ExchangeOperations.exec_swap2(ctx);
    return ();
}



