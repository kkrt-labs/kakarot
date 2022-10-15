// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
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
    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> model.Stack* {
        alloc_locals;
        let (elements: Uint256*) = alloc();
        return new model.Stack(elements=elements, raw_len=0);
    }

    // @notice Returns the length of the stack.
    // @param self - The pointer to the stack.
    // @return The length of the stack.
    func len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*
    ) -> felt {
        let actual_len = self.raw_len / element_size;
        return actual_len;
    }

    // @notice Push an element to the stack.
    // @param self - The pointer to the stack.
    // @param element - The element to push.
    // @return The new pointer to the stack.
    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, element: Uint256
    ) -> model.Stack* {
        alloc_locals;
        Stack.check_overlow(self);
        assert [self.elements + self.raw_len] = element;
        return new model.Stack(elements=self.elements, raw_len=self.raw_len + element_size);
    }

    // @notice Pop an element from the stack.
    // @param self - The pointer to the stack.
    // @return The new pointer to the stack.
    // @return The popped element.
    func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*
    ) -> (new_stack: model.Stack*, element: Uint256) {
        alloc_locals;
        Stack.check_underlow(self, 0);
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

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element to return.
    // @return The element at the given index.
    func peek{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, stack_index: felt
    ) -> Uint256 {
        alloc_locals;
        Stack.check_underlow(self, stack_index);
        let array_index = Stack.get_array_index(self, stack_index);
        return self.elements[array_index];
    }

    // @notice Check stack overflow.
    // @param self - The pointer to the stack.
    // @custom:revert if stack overflow.
    func check_overlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*
    ) {
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
    func check_underlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, stack_index: felt
    ) {
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
    func get_array_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, stack_index: felt
    ) -> felt {
        let stack_len = Stack.len(self);
        let array_index = stack_len - 1 - stack_index;
        return array_index;
    }

    // @notice Print the value of an element at a given stack index.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element.
    // @custom:use_hint
    func print_element_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, stack_index: felt
    ) {
        let element = Stack.peek(self, stack_index);
        %{
            element_str = cairo_uint256_to_str(ids.element)
            print(f"{ids.stack_index} - {element_str}")
        %}
        return ();
    }

    // @notice Print the stack.
    // @param self - The pointer to the stack.
    func dump{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(self: model.Stack*) {
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
    func inner_dump{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack*, stack_index: felt, last_index: felt
    ) {
        Stack.print_element_at(self, stack_index);
        if (stack_index == last_index) {
            return ();
        }
        return inner_dump(self, stack_index + 1, last_index);
    }
}
