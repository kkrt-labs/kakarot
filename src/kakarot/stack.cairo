// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
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
    func init() -> model.Stack* {
        alloc_locals;
        let (elements: Uint256*) = alloc();
        return new model.Stack(elements=elements, raw_len=0);
    }

    // @notice Returns the length of the stack.
    // @param self - The pointer to the stack.
    // @return The length of the stack.
    func len(self: model.Stack*) -> felt {
        let actual_len = self.raw_len / element_size;
        return actual_len;
    }

    // @notice Push an element to the stack.
    // @param self - The pointer to the stack.
    // @param element - The element to push.
    // @return The new pointer to the stack.
    func push{range_check_ptr}(self: model.Stack*, element: Uint256) -> model.Stack* {
        alloc_locals;
        Stack.check_overflow(self=self);
        assert [self.elements + self.raw_len] = element;
        return new model.Stack(elements=self.elements, raw_len=self.raw_len + element_size);
    }

    // @notice Pop an element from the stack.
    // @param self - The pointer to the stack.
    // @return The new pointer to the stack.
    // @return The popped element.
    func pop{range_check_ptr}(self: model.Stack*) -> (new_stack: model.Stack*, element: Uint256) {
        alloc_locals;
        Stack.check_underflow(self=self, stack_index=0);
        // Get last element
        let len = Stack.len(self=self);
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
    func pop_n{range_check_ptr}(self: model.Stack*, n: felt) -> (
        new_stack: model.Stack*, elements: Uint256*
    ) {
        alloc_locals;
        Stack.check_underflow(self=self, stack_index=n - 1);
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
    func peek{range_check_ptr}(self: model.Stack*, stack_index: felt) -> Uint256 {
        alloc_locals;
        Stack.check_underflow(self=self, stack_index=stack_index);
        let array_index = Stack.get_array_index(self=self, stack_index=stack_index);
        return self.elements[array_index];
    }

    // @notice Swap two elements in the stack.
    // @dev i is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param i - The index of the second element to swap.
    // @return The new pointer to the stack.
    func swap_i{range_check_ptr}(self: model.Stack*, i: felt) -> model.Stack* {
        alloc_locals;
        let element = Stack.peek(self=self, stack_index=i);  // get element to swap

        // convert stack index to array representing the stack index
        let array_index = Stack.get_array_index(self=self, stack_index=i);
        let array_index = 2 * array_index;  // convert the Uint256 array index to felt array index
        let (dst_elts: felt*) = alloc();  // new segment for stack copy
        let src_elts = cast(self.elements, felt*);  // convert Uint256* to felt*

        memcpy(dst=dst_elts, src=src_elts, len=array_index);  // copy the stack until the swaped elt
        assert [dst_elts + array_index] = src_elts[self.raw_len - 2];  // save the swaped elt low
        assert [dst_elts + array_index + 1] = src_elts[self.raw_len - 1];  // save the swaped elt high

        // copy the reset of the stack
        memcpy(
            dst=dst_elts + array_index + 2,
            src=src_elts + array_index + 2,
            len=self.raw_len - array_index - 4,
        );

        assert dst_elts[self.raw_len - 2] = element.low;  // copy swaped elt low to top of the stack
        assert dst_elts[self.raw_len - 1] = element.high;  // copy swaped elt high to top of the stack

        let elements = cast(dst_elts, Uint256*);  // cast dest to Uint256* to recreate a stack
        return new model.Stack(elements=elements, raw_len=self.raw_len);
    }

    // @notice Check stack overflow.
    // @param self - The pointer to the stack.
    // @custom:revert if stack overflow.
    func check_overflow{range_check_ptr}(self: model.Stack*) {
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
    func check_underflow{range_check_ptr}(self: model.Stack*, stack_index: felt) {
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
    func get_array_index(self: model.Stack*, stack_index: felt) -> felt {
        let stack_len = Stack.len(self);
        let array_index = stack_len - 1 - stack_index;
        return array_index;
    }
}
