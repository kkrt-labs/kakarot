// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_lt_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.constants import Constants
from kakarot.model import model

// @title Stack related functions.
// @notice This file contains functions related to the stack.
// @author @abdelhamidbakhta
// @custom:namespace Stack
// @custom:model model.Stack
namespace Stack {
    const element_size = Uint256.SIZE;

    // @notice Initialize the stack.
    // @return stack_ptr - The pointer to the stack.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> model.Stack* {
        alloc_locals;
        let (elements: Uint256*) = alloc();
        return new model.Stack(elements=elements, raw_len=0);
    }

    // @notice Returns the length of the stack.
    // @param self - The pointer to the stack.
    // @return The length of the stack.
    func len{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*) -> felt {
        let actual_len = self.raw_len / element_size;
        return actual_len;
    }

    // @notice Push an element to the stack.
    // @param self - The pointer to the stack.
    // @param element - The element to push.
    // @return The new pointer to the stack.
    func push{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, element: Uint256) -> model.Stack* {
        alloc_locals;
        Stack.check_overflow(self);
        assert [self.elements + self.raw_len] = element;
        return new model.Stack(elements=self.elements, raw_len=self.raw_len + element_size);
    }

    // @notice Pop an element from the stack.
    // @param self - The pointer to the stack.
    // @return The new pointer to the stack.
    // @return The popped element.
    func pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*) -> (new_stack: model.Stack*, element: Uint256) {
        alloc_locals;
        Stack.check_underflow(self, 0);
        // Get last element
        let len = Stack.len(self);
        let element = self.elements[len - 1];
        // Get new segment for next stack copy
        let (new_elements: Uint256*) = alloc();
        // Get length of new stack copy
        let new_len = self.raw_len - element_size;
        // Copy stack without last element
        memcpy(dst=new_elements, src=self.elements, len=new_len);
        // Create new stack
        local new_stack: model.Stack* = new model.Stack(elements=new_elements, raw_len=new_len);
        return (new_stack=new_stack, element=element);
    }

    // @notice Pop N elements from the stack.
    // @param self - The pointer to the stack.
    // @param len - The len of elements to pop.
    // @return The new pointer to the stack.
    // @return elements the pointer to the first popped element.
    func pop_n{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, n: felt) -> (new_stack: model.Stack*, elements: Uint256*) {
        alloc_locals;
        Stack.check_underflow(self, n - 1);
        // Get new segment for next stack copy
        let (new_elements: Uint256*) = alloc();
        // Get length of new stack copy
        let new_len = self.raw_len - (element_size * n);
        // Copy stack without last N elements
        memcpy(dst=new_elements, src=self.elements, len=new_len);

        // Create new stack
        local new_stack: model.Stack* = new model.Stack(elements=new_elements, raw_len=new_len);
        // Return new stack & pointer to first popped element
        return (new_stack=new_stack, elements=self.elements + new_len);
    }

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element to return.
    // @return The element at the given index.
    func peek{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index: felt) -> Uint256 {
        alloc_locals;
        Stack.check_underflow(self, stack_index);
        let array_index = Stack.get_array_index(self, stack_index);
        return self.elements[array_index];
    }

    // @notice Swap two elements in the stack.
    // @dev stack_index_1 and stack_index_2 are 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param stack_index_1 - The index of the first element to swap.
    // @param stack_index_2 - The index of the second element to swap.
    // @return The new pointer to the stack.
    func swap{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index_1: felt, stack_index_2: felt) -> model.Stack* {
        alloc_locals;
        // Retrieve elements at specified indexes
        let element_1 = Stack.peek(self, stack_index_1);
        let element_2 = Stack.peek(self, stack_index_2);

        // Source stack is the initial stack
        let src_stack = self;
        // Destination stack is a new stack with no initial elements
        let dst_stack: model.Stack* = Stack.init();
        // Get the lenght of the source stack
        let stack_len = Stack.len(self);
        // Start index is the index of the last element in the source stack
        let start_index = stack_len - 1;
        // Last index is the second element of the stack
        let last_index = 1;
        // At stack_index_2 we will push element_1
        let exception_index = stack_index_2;
        let exception_value = element_1;
        // After the stack copy, we will push element_2 at the top value of the new stack
        let top_value = element_2;

        // Copy stack
        let (src_stack, dst_stack) = Stack.copy_except_at_index(
            src_stack, dst_stack, start_index, last_index, exception_index, exception_value
        );
        // Push the top value and return the new stack
        return Stack.push(dst_stack, top_value);
    }

    // @notice Copy a segment of the stack except at a given index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param src_stack - The pointer to the source stack.
    // @param dst_stack - The pointer to the destination stack.
    // @param start_index - The index of the first element to copy.
    // @param last_index - The index of the last element to copy.
    // @param exception_index - The index of the element with an exception value.
    // @param exception_value - The exception value.
    // @return The new pointer to the source stack.
    // @return The new pointer to the destination stack.
    func copy_except_at_index{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        src_stack: model.Stack*,
        dst_stack: model.Stack*,
        start_index: felt,
        last_index: felt,
        exception_index: felt,
        exception_value: Uint256,
    ) -> (src_stack: model.Stack*, dst_stack: model.Stack*) {
        alloc_locals;
        // If the index is the exception index, push the exception value
        if (start_index == exception_index) {
            let dst_stack = Stack.push(dst_stack, exception_value);
        } else {
            // Otherwise, push the value at the source index
            let element = Stack.peek(src_stack, start_index);
            let dst_stack = Stack.push(dst_stack, element);
        }

        // If the index is the last index, we are done and we can return the new stacks
        if (start_index == last_index) {
            return (src_stack=src_stack, dst_stack=dst_stack);
        }
        let new_start_index = start_index - 1;
        return copy_except_at_index(
            src_stack, dst_stack, new_start_index, last_index, exception_index, exception_value
        );
    }

    // @notice Check stack overflow.
    // @param self - The pointer to the stack.
    // @custom:revert if stack overflow.
    func check_overflow{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*) {
        let stack_len = Stack.len(self);
        // Revert if stack overflow
        with_attr error_message("Kakarot: StackOverflow") {
            assert_lt_felt(stack_len, Constants.STACK_MAX_DEPTH);
        }
        return ();
    }

    // @notice Check stack underflow.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element.
    // @custom:revert if stack underflow.
    func check_underflow{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index: felt) {
        alloc_locals;
        let stack_len = Stack.len(self);
        // Revert if stack underflow
        with_attr error_message("Kakarot: StackUnderflow") {
            assert_lt_felt(stack_index, stack_len);
        }
        return ();
    }

    // @notice Get the array index of the element at a given stack index.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element.
    // @return The array index of the element.
    func get_array_index{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index: felt) -> felt {
        let stack_len = Stack.len(self);
        let array_index = stack_len - 1 - stack_index;
        return array_index;
    }

    // @notice Print the value of an element at a given stack index.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element.
    // @custom:use_hint
    func print_element_at{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index: felt) {
        let element = Stack.peek(self, stack_index);
        %{
            import logging
            element_str = cairo_uint256_to_str(ids.element)
            logging.info(f"{ids.stack_index} - {element_str}")
        %}
        return ();
    }

    // @notice Print the stack.
    // @param self - The pointer to the stack.
    func dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*) {
        let stack_len = Stack.len(self);
        if (stack_len == 0) {
            return ();
        }
        let last_index = stack_len - 1;
        inner_dump(self, 0, last_index);
        return ();
    }

    // @notice Recursively print the stack.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element.
    // @param last_index - The index of the last element.
    func inner_dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Stack*, stack_index: felt, last_index: felt) {
        Stack.print_element_at(self, stack_index);
        if (stack_index == last_index) {
            return ();
        }
        return inner_dump(self, stack_index + 1, last_index);
    }
}
