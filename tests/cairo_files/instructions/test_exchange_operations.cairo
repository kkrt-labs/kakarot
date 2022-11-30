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

// @notice Prepare a stack with `stack_len` elements to test swap logic. 
func prepare_stack{range_check_ptr}(stack_len : felt, preswap_idx: felt, preswap_idx_value: Uint256, top_stack_element_value: Uint256,  stack : model.Stack*) -> (prepared_stack: model.Stack*) {
    alloc_locals;
    // We set the last prepared_stack_len to a special number so we can test for successful swapping
    if (stack_len == 0) {
        let updated_stack: model.Stack* = Stack.push(stack, top_stack_element_value);
        return (prepared_stack=updated_stack);    
    }
    // As well as user defined prepared_stack_len
    if (preswap_idx == stack_len) {
        let _updated_stack: model.Stack* = Stack.push(stack, preswap_idx_value);
        let updated_stack : model.Stack* = prepare_stack(stack_len=stack_len-1, preswap_idx=preswap_idx, preswap_idx_value=preswap_idx_value, top_stack_element_value=top_stack_element_value, stack=_updated_stack);
        return (prepared_stack=updated_stack);
    }

    // otherwise we just fill with zero
    let _updated_stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let updated_stack : model.Stack* = prepare_stack(stack_len=stack_len-1, preswap_idx=preswap_idx, preswap_idx_value=preswap_idx_value, top_stack_element_value=top_stack_element_value, stack=_updated_stack);
    return (prepared_stack=updated_stack);
}

// @notice Checks if previously prepared stack has its values properly swapped.
func check_swapped_stack{range_check_ptr}(preswap_top_stack_element: Uint256, preswap_element_at_swapped_idx: Uint256, swapped_idx: felt, stack : model.Stack*) {
   alloc_locals;
   let swapped_element = Stack.peek(stack, 0);
   let swapped_element_at_swapped_idx =  Stack.peek(stack, swapped_idx);
  
   assert_uint256_eq(preswap_top_stack_element, swapped_element_at_swapped_idx);
   assert_uint256_eq(preswap_element_at_swapped_idx, swapped_element);
   return ();
}

@external
func test__util_prepare_stack__should_create_stack_with_top_and_preswapped_elements{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    let stack: model.Stack* = Stack.init();
    let top_stack_element_value : Uint256 = Uint256(2, 0);
    let preswap_element_at_idx : Uint256 = Uint256(1, 0);
    let length_of_stack_indexed_from_zero = 5;

    // When
    let prepared_stack : model.Stack* = prepare_stack(stack_len=length_of_stack_indexed_from_zero, preswap_idx=2, preswap_idx_value=preswap_element_at_idx, top_stack_element_value=top_stack_element_value, stack=stack);

    // Then 
   let stack_len = Stack.len(prepared_stack);
   let top_element = Stack.peek(prepared_stack, 0);
   let element_at_preswap_idx =  Stack.peek(prepared_stack, 2);
  
   assert stack_len = length_of_stack_indexed_from_zero + 1;
   assert_uint256_eq(top_element, top_stack_element_value);
   assert_uint256_eq(element_at_preswap_idx, preswap_element_at_idx);

    return ();
}

@external
func test__exec_swap1__should_swap_1st_and_2nd{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {

    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let top_stack_element_value : Uint256 = Uint256(2, 0);
    let preswap_element_at_idx : Uint256 = Uint256(1, 0);
    let prepped_stack : model.Stack* = prepare_stack(stack_len=1, preswap_idx=1, preswap_idx_value=preswap_element_at_idx, top_stack_element_value=top_stack_element_value, stack=stack);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, prepped_stack);

    // When
    let result =  ExchangeOperations.exec_swap1(ctx);

    // Then
    check_swapped_stack(preswap_top_stack_element=top_stack_element_value, preswap_element_at_swapped_idx=preswap_element_at_idx, swapped_idx=1, stack=result.stack);
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
func test__exec_swap2__should_swap_1st_and_3rd{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {

    alloc_locals;
    // Given
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let top_stack_element_value : Uint256 = Uint256(2, 0);
    let preswap_element_at_idx : Uint256 = Uint256(1, 0);
    let prepared_stack : model.Stack* = prepare_stack(stack_len=2, preswap_idx=2, preswap_idx_value=preswap_element_at_idx, top_stack_element_value=top_stack_element_value, stack=stack);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, prepared_stack);

    // When
    let result =  ExchangeOperations.exec_swap2(ctx);

    // Then
    check_swapped_stack(preswap_top_stack_element=Uint256(2, 0), preswap_element_at_swapped_idx=Uint256(1, 0), swapped_idx=2, stack=result.stack);
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



