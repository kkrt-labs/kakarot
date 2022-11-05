// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack

@view
func __setup__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ();
}

@external
func test__init__should_return_an_empty_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let result: model.Stack* = Stack.init();

    // Then
    assert result.raw_len = 0;
    return ();
}

@external
func test__len__should_return_the_length_of_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();

    // When
    let result: felt = Stack.len(stack);

    // Then
    assert result = 0;
    return ();
}

@external
func test__push__should_add_an_element_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();

    // When
    let result: model.Stack* = Stack.push(stack, Uint256(1, 0));

    // Then
    let len: felt = Stack.len(result);
    assert len = 1;
    return ();
}

@external
func test__pop__should_pop_an_element_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (stack, element) = Stack.pop(stack);

    // Then
    assert element = Uint256(3, 0);
    assert stack.raw_len = (3 - 1) * 2;
    return ();
}

@external
func test__pop__should_pop_N_elements_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (stack, elements) = Stack.pop_n(stack, 3);

    // Then
    assert elements[2] = Uint256(3, 0);
    assert elements[1] = Uint256(2, 0);
    assert elements[0] = Uint256(1, 0);
    assert stack.raw_len = 0;
    return ();
}

@external
func test__pop__should_fail__when_stack_underflow_pop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();

    // When & Then
    let (stack, element) = Stack.pop(stack);
    return ();
}

@external
func test__pop__should_fail__when_stack_underflow_pop_n{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));

    // When & Then
    let (stack, elements) = Stack.pop_n(stack, 2);
    return ();
}

@external
func test__peek__should_return_stack_at_given_index__when_value_is_0{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let result = Stack.peek(stack, 0);

    // Then
    assert result = Uint256(3, 0);
    return ();
}

@external
func test__peek__should_return_stack_at_given_index__when_value_is_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let result = Stack.peek(stack, 1);

    // Then
    assert result = Uint256(2, 0);
    return ();
}

@external
func test__peek__should_fail_when_underflow{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();

    // When & Then
    let result = Stack.peek(stack, 1);
    return ();
}

@external
func test__swap__should_swap_2_stacks{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
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

    // When
    let result = Stack.swap_i(stack, i=2);

    // Then
    let index3 = Stack.peek(result, 3);
    assert index3 = Uint256(1, 0);
    let index2 = Stack.peek(result, 2);
    assert index2 = Uint256(4, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(3, 0);
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(2, 0);
    return ();
}

@external
func test__swap__should_fail__when_index_1_is_underflow{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();

    // When & Then
    let result = Stack.swap_i(stack, 1);
    return ();
}

@external
func test__swap__should_fail__when_index_2_is_underflow{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));

    // When & Then
    let result = Stack.swap_i(stack, 1);
    return ();
}

@external
func test__dump__should_print_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    Helpers.setup_python_defs();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When & Then
    let result = Stack.dump(stack);
    return ();
}
