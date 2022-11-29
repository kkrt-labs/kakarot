// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.constants import Constants
from kakarot.model import model

// New Stack dependencies
from starkware.cairo.common.dict import DictAccess, dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.math import unsigned_div_rem
from utils.utils import Helpers



// @title Stack related functions.
// @notice This file contains functions related to the stack.
// @author @abdelhamidbakhta
// @custom:namespace Stack
// @custom:model model.Stack
namespace Stack {
    // New Code
    // Summary of stack. Created upon finalization of the stack.
    struct Summary {
        stack_16bytes_len: felt,
        stack_squashed_start: DictAccess*,
        stack_squashed_end: DictAccess*,
    }

    // @notice Initialize the stack.
    // @return The pointer to the stack.
    // TODO: Maybe use Stack elements directly instead of bytes
    func init() -> model.Stack* {
        alloc_locals;
        let (stack_word_dict_start: DictAccess*) = default_dict_new(0);
        return new model.Stack(
            stack_word_dict_start=stack_word_dict_start,
            stack_word_dict=stack_word_dict_start,
            stack_16bytes_len=0);
    }

    // @notice Finalizes the stack.
    // @return The pointer to the stack Summary.
    func finalize{range_check_ptr}(self: model.Stack*) -> Summary* {
        let (squashed_start, squashed_end) = default_dict_finalize(
            self.stack_word_dict_start, self.stack_word_dict, 0
        );
        return new Summary(
            stack_16bytes_len=self.stack_16bytes_len, stack_squashed_start=squashed_start, stack_squashed_end=squashed_end
            );
    }

    // @notice Store an element into the stack.
    // @param self - The pointer to the stack.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the stack.
    func push{range_check_ptr}(self: model.Stack*, element: Uint256) -> model.Stack* {
        let stack_word_dict = self.stack_word_dict;
        let position_zero = self.stack_16bytes_len;

        // Check if Stack will overflow
        with_attr error_message("Kakarot: StackOverflow") {
            assert_le(position_zero, Constants.STACK_MAX_DEPTH * 2);
        }        

        // Add Uint256 low and high to Dict
        dict_write{dict_ptr=stack_word_dict}(position_zero, element.high);
        dict_write{dict_ptr=stack_word_dict}(position_zero + 1, element.low);

        // Return new Stack
        return (new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_16bytes_len=self.stack_16bytes_len + 2,
            ));
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
        let stack_word_dict = self.stack_word_dict;
        let position_zero = self.stack_16bytes_len;

        // Check if there is underflow
        with_attr error_message("Kakarot: StackUnderflow") {
            assert_le(n * 2, position_zero);
        }        

        let (new_elements: Uint256*) = alloc();
        // Read and Copy the elements on an array

        // Generate an array of Uint256* to return
        let (stack_word_dict) = dict_copy(
            stack_word_dict=stack_word_dict, stack_len=position_zero, n=n * 2, output=new_elements
        );

        // Return Stack with updated Len
        let popped_len = 2 * n;
        return (
            new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_16bytes_len=self.stack_16bytes_len - reduce,
            ),
            new_elements,
        );
    }

    func dict_copy{range_check_ptr}(
        stack_word_dict: DictAccess*, stack_len: felt, n: felt, output: Uint256*
    ) -> (stack_word_dict: DictAccess*) {
        if (n == 0) {
            return (stack_word_dict=stack_word_dict);
        }

        // Get Low and High of element at position N
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(stack_len - n);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(stack_len - n + 1);

        // Save Uint256 value in array
        let n_index = n / 2 - 1;
        assert output[n_index] = Uint256(low=el_low, high=el_high);

        return dict_copy(
            stack_word_dict=stack_word_dict, stack_len=stack_len, n=n - 2, output=output
        );
    }

    // @notice Pop an element from the stack.
    // @param self - The pointer to the stack.
    // @return The new pointer to the stack.
    // @return The popped element.
    func pop{range_check_ptr}(self: model.Stack*) -> (new_stack: model.Stack*, element: Uint256) {
        let stack_word_dict = self.stack_word_dict;
        let position_zero = self.stack_16bytes_len;
        // Check if stack will underflow
        with_attr error_message("Kakarot: StackUnderflow") {
            assert_le(2, position_zero);
        }


        // Read and Copy element at position 1(first on stack)
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(position_zero - 2);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(position_zero - 1);

        // Update and return Stack
        return (
            new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_16bytes_len=self.stack_16bytes_len - 2,
            ),
            Uint256(low=el_low, high=el_high),
        );
    }

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element to return.
    // @return The element at the given index.
    func peek{range_check_ptr}(self: model.Stack*, stack_index: felt) -> (
        self: model.Stack*, value: Uint256
    ) {
        let stack_word_dict = self.stack_word_dict;
        let position_zero = self.stack_16bytes_len;
        // Check if there is underflow
        with_attr error_message("Kakarot: StackUnderflow") {
            assert_le(stack_index * 2, position_zero);
        }        
        // Read element at position "stack_index"
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(position_zero - stack_index * 2 - 2);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(position_zero - stack_index * 2 - 1);
        // Return element
        return (
            new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_16bytes_len=self.stack_16bytes_len,
            ),
            Uint256(low=el_low, high=el_high),
        );
    }

    // @notice Swap two elements in the stack.
    // @dev i is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param i - The index of the second element to swap.
    // @return The new pointer to the stack.
    func swap_i{range_check_ptr}(self: model.Stack*, i: felt) -> model.Stack* {
        let stack_word_dict = self.stack_word_dict;
        let position_zero = self.stack_16bytes_len;

        // Check if there is underflow
        with_attr error_message("Kakarot: StackUnderflow") {
            assert_le(i * 2, position_zero);
        }        

        // Read elements at stack postition 1
        let (el1_high) = dict_read{dict_ptr=stack_word_dict}(position_zero - 2);
        let (el1_low) = dict_read{dict_ptr=stack_word_dict}(position_zero - 1);
        // Read elements at stack postition N
        let (el2_high) = dict_read{dict_ptr=stack_word_dict}(position_zero - i * 2);
        let (el2_low) = dict_read{dict_ptr=stack_word_dict}(position_zero - i * 2 + 1);

        // Swap elements
        dict_write{dict_ptr=stack_word_dict}(position_zero - 2, el2_high);
        dict_write{dict_ptr=stack_word_dict}(position_zero - 1, el2_low);
        dict_write{dict_ptr=stack_word_dict}((position_zero - i * 2), el1_high);
        dict_write{dict_ptr=stack_word_dict}((position_zero - i * 2 + 1), el1_low);

        // Return Stack
        return (
            new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_16bytes_len=self.stack_16bytes_len,
            ));
    }

}
