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

// @notice Prepare a stack with `idx` elements to test swap logic. 
func prep_stack{range_check_ptr}(idx : felt, to_swap_idx: felt,  stack : model.Stack*) -> (prepped_stack: model.Stack*) {
    alloc_locals;
    // We set the last idx to a special number so we can test for successful swapping
    if (idx == 0) {
        let updated_stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
        return (prepped_stack=updated_stack);    
    }
    // As well as user defined idx
    if (to_swap_idx == idx) {
        let _updated_stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
        let updated_stack : model.Stack* = prep_stack(idx=idx-1, to_swap_idx=to_swap_idx, stack=_updated_stack);
        return (prepped_stack=updated_stack);
    }

    // otherwise we just fill with zero
    let _updated_stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let updated_stack : model.Stack* = prep_stack(idx=idx-1, to_swap_idx=to_swap_idx, stack=_updated_stack);
    return (prepped_stack=updated_stack);
}

// @notice Checks if previously prepared stack has its values properly swapped.
func check_stack{range_check_ptr}(idx : felt, swapped_idx: felt,  stack : model.Stack*) {
    alloc_locals;
    let swapped = Stack.peek(stack, idx);
    if (idx == 0) {
        assert swapped = Uint256(1,0);
        return ();    
    }
    // As well as the first
    if (swapped_idx == idx) {
        assert swapped = Uint256(2,0);
    } else {
        assert swapped = Uint256(0,0);        
    }

    check_stack(idx=idx-1, swapped_idx=swapped_idx, stack=stack);
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
    let prepped_stack : model.Stack* = prep_stack(idx=1, to_swap_idx=1, stack=stack);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, prepped_stack);

    // When
    let result =  ExchangeOperations.exec_swap1(ctx);

    // Then
    check_stack(idx=1, swapped_idx=1, stack=result.stack);
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
    let prepped_stack : model.Stack* = prep_stack(idx=2, to_swap_idx=2, stack=stack);
    
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, prepped_stack);

    // When
    let result =  ExchangeOperations.exec_swap2(ctx);

    // Then
    check_stack(idx=2, swapped_idx=2, stack=result.stack);
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



