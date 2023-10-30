// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import DictAccess, dict_read, dict_write
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.constants import Constants
from kakarot.model import model
from utils.utils import Helpers

// @title Stack related functions.
// @notice This file contains functions related to the stack.
namespace Stack {
    // Summary of stack. Created upon finalization of the stack.
    struct Summary {
        squashed_start: DictAccess*,
        squashed_end: DictAccess*,
        size: felt,
    }

    // @notice Initialize the stack.
    // @return The pointer to the stack.
    func init() -> model.Stack* {
        alloc_locals;
        let (dict_ptr_start: DictAccess*) = default_dict_new(0);
        return new model.Stack(dict_ptr_start, dict_ptr_start, 0);
    }

    // @notice Finalizes the stack.
    // @param self The pointer to the stack.
    // @return summary The pointer to the stack Summary.
    func finalize{range_check_ptr}(self: model.Stack*) -> Summary* {
        let (squashed_start, squashed_end) = default_dict_finalize(
            self.dict_ptr_start, self.dict_ptr, 0
        );
        return new Summary(squashed_start, squashed_end, self.size);
    }

    // @notice Store an element into the stack.
    // @param self The pointer to the stack.
    // @param element The element to push.
    // @return stack The new pointer to the stack.
    func push{range_check_ptr}(self: model.Stack*, element: Uint256*) -> model.Stack* {
        let dict_ptr = self.dict_ptr;
        with dict_ptr {
            dict_write(self.size, cast(element, felt));
        }

        return new model.Stack(self.dict_ptr_start, dict_ptr, self.size + 1);
    }

    // @notice Store a uint128 into the stack.
    // @param self The pointer to the stack.
    // @param element The element to push.
    // @return stack The new pointer to the stack.
    func push_uint128{range_check_ptr}(self: model.Stack*, element: felt) -> model.Stack* {
        tempvar item = new Uint256(element, 0);

        return push(self, item);
    }

    // @notice Pop N elements from the stack.
    // @param self The pointer to the stack.
    // @param n The len of elements to pop.
    // @return stack The new pointer to the stack.
    // @return elements The pointer to the first popped element.
    func pop_n{range_check_ptr}(self: model.Stack*, n: felt) -> (
        stack: model.Stack*, elements: Uint256*
    ) {
        alloc_locals;
        let dict_ptr = self.dict_ptr;

        let (local items: felt*) = alloc();
        with dict_ptr {
            Internals._read_n(index=self.size - 1, n=n, output=items);
        }

        return (
            new model.Stack(self.dict_ptr_start, dict_ptr, self.size - n), cast(items, Uint256*)
        );
    }

    // @notice Pop an element from the stack.
    // @param self The pointer to the stack.
    // @return stack The new pointer to the stack.
    // @return element The popped element.
    func pop{range_check_ptr}(self: model.Stack*) -> (stack: model.Stack*, element: Uint256*) {
        let dict_ptr = self.dict_ptr;

        with dict_ptr {
            let (pointer) = dict_read(self.size - 1);
        }

        return (
            new model.Stack(self.dict_ptr_start, dict_ptr, self.size - 1), cast(pointer, Uint256*)
        );
    }

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param self The pointer to the stack.
    // @param stack_index The index of the element to return.
    // @return self The new pointer to the stack.
    // @return value The element at the given index.
    func peek{range_check_ptr}(self: model.Stack*, stack_index: felt) -> (
        self: model.Stack*, value: Uint256*
    ) {
        let dict_ptr = self.dict_ptr;

        with dict_ptr {
            let (pointer) = dict_read(self.size - 1 - stack_index);
        }

        return (new model.Stack(self.dict_ptr_start, dict_ptr, self.size), cast(pointer, Uint256*));
    }

    // @notice Swap two elements in the stack.
    // @dev i is 0-based, 0 is the top of the stack.
    // @param self The pointer to the stack.
    // @param i The index of the second element to swap.
    // @return stack The new pointer to the stack.
    func swap_i{range_check_ptr}(self: model.Stack*, i: felt) -> model.Stack* {
        let dict_ptr = self.dict_ptr;

        with dict_ptr {
            let (pointer_top) = dict_read(self.size - 1);
            let (pointer_i) = dict_read(self.size - 1 - i);

            dict_write(self.size - 1, pointer_i);
            dict_write(self.size - 1 - i, pointer_top);
        }

        return (new model.Stack(self.dict_ptr_start, dict_ptr, self.size));
    }
}

namespace Internals {
    func _read_n{range_check_ptr, dict_ptr: DictAccess*}(index: felt, n: felt, output: felt*) {
        if (n == 0) {
            return ();
        }

        let (pointer) = dict_read(index);
        let item = cast(pointer, felt*);
        assert [output] = [item];
        assert [output + 1] = [item + 1];

        return _read_n(index - 1, n - 1, output + 2);
    }
}
