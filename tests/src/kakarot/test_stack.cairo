// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.uint256 import assert_uint256_eq

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack

@external
func test__init__should_return_an_empty_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let result = Stack.init();

    // Then
    assert result.size = 0;
    return ();
}

@external
func test__push__should_add_an_element_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let stack = Stack.init();

    // When
    let result = Stack.push_uint128(stack, 1);

    // Then
    assert result.size = 1;
    return ();
}

@external
func test__pop__should_pop_an_element_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    // When
    let (stack, element) = Stack.pop(stack);

    // Then
    assert stack.size = 2;
    assert_uint256_eq([element], [item_0]);
    return ();
}

@external
func test__pop__should_pop_N_elements_to_the_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    // When
    let (stack, local elements) = Stack.pop_n(stack, 3);

    // Then
    assert_uint256_eq(elements[0], Uint256(1, 0));
    assert_uint256_eq(elements[1], Uint256(2, 0));
    assert_uint256_eq(elements[2], Uint256(3, 0));

    assert stack.size = 0;
    return ();
}

@external
func test__peek__should_return_stack_at_given_index__when_value_is_0{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    // When
    let (stack, result) = Stack.peek(stack, 0);

    // Then
    assert_uint256_eq([result], [item_0]);
    return ();
}

@external
func test__peek__should_return_stack_at_given_index__when_value_is_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    // When
    let (stack, result) = Stack.peek(stack, 1);

    // Then
    assert_uint256_eq([result], [item_1]);
    return ();
}

@external
func test__swap__should_swap_2_stacks{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    // Given
    tempvar item_0 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(2, 0);
    tempvar item_2 = new Uint256(3, 0);
    tempvar item_3 = new Uint256(4, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_3);
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    // When
    let result = Stack.swap_i(stack, i=3);

    // Then
    let (stack, index3) = Stack.peek(result, 3);
    assert_uint256_eq([index3], [item_0]);
    let (stack, index2) = Stack.peek(stack, 2);
    assert_uint256_eq([index2], [item_2]);
    let (stack, index1) = Stack.peek(stack, 1);
    assert_uint256_eq([index1], [item_1]);
    let (stack, index0) = Stack.peek(stack, 0);
    assert_uint256_eq([index0], [item_3]);
    return ();
}
