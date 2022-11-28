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

//New Stack dependencies
from starkware.cairo.common.dict import DictAccess, dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.math import unsigned_div_rem


// @title Stack related functions.
// @notice This file contains functions related to the stack.
// @author @abdelhamidbakhta
// @custom:namespace Stack
// @custom:model model.Stack
namespace Stack {
    // New Code
    // Summary of stack. Created upon finalization of the stack.
    struct Summary {
        stack_bytes_len: felt,
        stack_squashed_start: DictAccess*,
        stack_squashed_end: DictAccess*,
    }
     
    // @notice Initialize the stack.
    // @return The pointer to the stack.
    //TODO: Maybe use Stack elements directly instead of bytes
    func init() -> model.Stack* {
        alloc_locals;
        let (stack_word_dict_start: DictAccess*) = default_dict_new(0);
        return new model.Stack(
            stack_word_dict_start=stack_word_dict_start,
            stack_word_dict=stack_word_dict_start,
            stack_bytes_len=0);
    }


    // @notice Finalizes the stack.
    // @return The pointer to the stack Summary.
    func finalize{range_check_ptr}(self: model.Stack*) -> Summary* {
        let (squashed_start, squashed_end) = default_dict_finalize(
            self.stack_word_dict_start, self.stack_word_dict, 0
        );
        return new Summary(
            stack_bytes_len=self.stack_bytes_len, stack_squashed_start=squashed_start, stack_squashed_end=squashed_end
            );
    }        


    // @notice Store an element into the stack.
    // @param self - The pointer to the stack.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the stack.
    func push{range_check_ptr}(
        self: model.Stack*, element: Uint256
    ) -> model.Stack* {
        let stack_word_dict = self.stack_word_dict;

        // // Compute new bytes_len.
        // let new_min_bytes_len = Helpers.ceil_bytes_len_to_next_32_bytes_word(offset + 32);

        // Check stack index to push
        let (chunk_index, offset_in_chunk) = unsigned_div_rem(self.stack_bytes_len+32, 16);
        // let new_stack_bytes_len = self.stack_bytes_len + 32

        // so we optimize for it. Note that no locals were allocated at all.
        dict_write{dict_ptr=stack_word_dict}(chunk_index, element.high);
        dict_write{dict_ptr=stack_word_dict}(chunk_index, element.low);
        return (new model.Stack(
            stack_word_dict_start=self.stack_word_dict_start,
            stack_word_dict=stack_word_dict,
            stack_bytes_len=self.stack_bytes_len + 32,
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

        let (stack_len, stack_rem) = unsigned_div_rem(self.stack_bytes_len, 16);
        let (new_elements : Uint256* ) = alloc();
        // Read and Copy the elements on an array
        dict_copy(stack_word_dict=stack_word_dict,stack_len=stack_len,n=n, output=new_elements);
        // Update Len
        // Return Stack with updated Len

        return (
                new model.Stack(
                    stack_word_dict_start=self.stack_word_dict_start,
                    stack_word_dict=stack_word_dict,
                    stack_bytes_len=self.stack_bytes_len - 32*n,
                ),
                new_elements,
                );
    }

    func dict_copy{range_check_ptr}(stack_word_dict: DictAccess*,stack_len:felt, n: felt, output:Uint256*){
        
        // N needs to be total (pop_len - 1)
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(stack_len - n);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(stack_len-n - 1);
        assert [output + n] = Uint256(low=el_low,high=el_high); 
        if(n == 0){
            return();
        }
        dict_copy(stack_word_dict=stack_word_dict,stack_len=stack_len,n=n-2,output=output);
        return();
    }   
    

    // @notice Pop an element from the stack.
    // @param self - The pointer to the stack.
    // @return The new pointer to the stack.
    // @return The popped element.
    func pop{range_check_ptr}(self: model.Stack*) -> (new_stack: model.Stack*, element: Uint256) {
        let stack_word_dict = self.stack_word_dict;

        let (stack_len, stack_rem) = unsigned_div_rem(self.stack_bytes_len, 16);
        // let (new_elements : Uint256* ) = alloc();    

        // Read and Copy the last element
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(stack_len);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(stack_len + 1);

        // Update and return Stack      

        return (
                new model.Stack(
                    stack_word_dict_start=self.stack_word_dict_start,
                    stack_word_dict=stack_word_dict,
                    stack_bytes_len = self.stack_bytes_len - 32,
                ),
                Uint256(low=el_low,high=el_high),
        );       
    }

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param stack_index - The index of the element to return.
    // @return The element at the given index.
    func peek{range_check_ptr}(self: model.Stack*, stack_index: felt) -> Uint256 {
        let stack_word_dict = self.stack_word_dict;
        // Read element at stack_index
        let (el_high) = dict_read{dict_ptr=stack_word_dict}(stack_index*2);
        let (el_low) = dict_read{dict_ptr=stack_word_dict}(stack_index*2 + 1);
        // Return element
        return (Uint256(low=el_low, high=el_high));
    }

    // @notice Swap two elements in the stack.
    // @dev i is 0-based, 0 is the top of the stack.
    // @param self - The pointer to the stack.
    // @param i - The index of the second element to swap.
    // @return The new pointer to the stack.
    func swap_i{range_check_ptr}(self: model.Stack*, i: felt) -> model.Stack* {
        let stack_word_dict = self.stack_word_dict;

        // Check stack index to swap
        let (stack_len, offset_in_chunk) = unsigned_div_rem(self.stack_bytes_len, 16);  

        // Read elements at stack a and b
        let (el1_high) = dict_read{dict_ptr=stack_word_dict}(stack_len);
        let (el1_low) = dict_read{dict_ptr=stack_word_dict}(stack_len+1);

        let (el2_high) = dict_read{dict_ptr=stack_word_dict}(i*2);
        let (el2_low) = dict_read{dict_ptr=stack_word_dict}(i*2 + 1);

        // Swap elements
        dict_write{dict_ptr=stack_word_dict}(stack_len, el2_high);
        dict_write{dict_ptr=stack_word_dict}(stack_len+1, el2_low);
        dict_write{dict_ptr=stack_word_dict}(i*2, el1_high);
        dict_write{dict_ptr=stack_word_dict}(i*2+1, el1_low);

        // Return Stack
        return (
                new model.Stack(
                    stack_word_dict_start=self.stack_word_dict_start,
                    stack_word_dict = stack_word_dict,
                    stack_bytes_len = self.stack_bytes_len,
                )
        );
    }
}
