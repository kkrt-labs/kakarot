// SPDX-License-Identifier: MIT

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import DictAccess, dict_read, dict_write
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.lang.compiler.lib.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

from kakarot.constants import Constants
from kakarot.model import model
from utils.utils import Helpers

// @title Stack related functions.
namespace Stack {
    // @notice Initialize the stack.
    // @return The pointer to the stack.
    func init() -> model.Stack* {
        let (dict_ptr_start: DictAccess*) = default_dict_new(0);
        return new model.Stack(dict_ptr_start, dict_ptr_start, 0);
    }

    // @notice Finalizes the stack.
    // @param stack The pointer to the stack.
    func finalize{range_check_ptr, stack: model.Stack*}() {
        let (squashed_start, squashed_end) = default_dict_finalize(
            stack.dict_ptr_start, stack.dict_ptr, 0
        );
        tempvar stack = new model.Stack(squashed_start, squashed_end, stack.size);
        return ();
    }

    // @notice Store an element into the stack.
    // @param stack The pointer to the stack.
    // @param element The element to push.
    // @return stack The new pointer to the stack.
    func push{stack: model.Stack*}(element: Uint256*) {
        let dict_ptr = stack.dict_ptr;
        with dict_ptr {
            dict_write(stack.size, cast(element, felt));
        }

        tempvar stack = new model.Stack(stack.dict_ptr_start, dict_ptr, stack.size + 1);
        return ();
    }

    // @notice Store a uint128 into the stack.
    // @param stack The pointer to the stack.
    // @param element The element to push.
    // @return stack The new pointer to the stack.
    func push_uint128{stack: model.Stack*}(element: felt) {
        alloc_locals;
        local item: Uint256 = Uint256(element, 0);
        let (__fp__, _) = get_fp_and_pc();
        push(&item);
        return ();
    }

    // @notice Store a uint128 into the stack.
    // @param stack The pointer to the stack.
    // @param element The element to push.
    // @return stack The new pointer to the stack.
    func push_uint256{stack: model.Stack*}(element: Uint256) {
        alloc_locals;
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;
        push(&element);
        return ();
    }

    // @notice Pop N elements from the stack.
    // @param stack The pointer to the stack.
    // @param n The len of elements to pop.
    // @return stack The new pointer to the stack.
    // @return elements The pointer to the first popped element.
    func pop_n{stack: model.Stack*}(n: felt) -> (elements: Uint256*) {
        alloc_locals;
        let dict_ptr = stack.dict_ptr;

        let (local items: felt*) = alloc();
        with dict_ptr {
            Internals._read_n(index=stack.size - 1, n=n, output=items);
        }

        tempvar stack = new model.Stack(stack.dict_ptr_start, dict_ptr, stack.size - n);
        return (cast(items, Uint256*),);
    }

    // @notice Pop an element from the stack.
    // @param stack The pointer to the stack.
    // @return stack The new pointer to the stack.
    // @return element The popped element.
    func pop{stack: model.Stack*}() -> (element: Uint256*) {
        let dict_ptr = stack.dict_ptr;

        with dict_ptr {
            let (pointer) = dict_read(stack.size - 1);
        }

        tempvar stack = new model.Stack(stack.dict_ptr_start, dict_ptr, stack.size - 1);
        return (cast(pointer, Uint256*),);
    }

    // @notice Return a value from the stack at a given stack index.
    // @dev stack_index is 0-based, 0 is the top of the stack.
    // @param stack The pointer to the stack.
    // @param stack_index The index of the element to return.
    // @return stack The new pointer to the stack.
    // @return value The element at the given index.
    func peek{stack: model.Stack*}(stack_index: felt) -> (value: Uint256*) {
        let dict_ptr = stack.dict_ptr;

        with dict_ptr {
            let (pointer) = dict_read(stack.size - 1 - stack_index);
        }

        tempvar stack = new model.Stack(stack.dict_ptr_start, dict_ptr, stack.size);

        return (cast(pointer, Uint256*),);
    }

    // @notice Swap two elements in the stack.
    // @dev i is 0-based, 0 is the top of the stack.
    // @param stack The pointer to the stack.
    // @param i The index of the second element to swap.
    // @return stack The new pointer to the stack.
    func swap_i{stack: model.Stack*}(i: felt) {
        let dict_ptr = stack.dict_ptr;

        with dict_ptr {
            let (pointer_top) = dict_read(stack.size - 1);
            let (pointer_i) = dict_read(stack.size - 1 - i);

            dict_write(stack.size - 1, pointer_i);
            dict_write(stack.size - 1 - i, pointer_top);
        }

        tempvar stack = new model.Stack(stack.dict_ptr_start, dict_ptr, stack.size);

        return ();
    }
}

namespace Internals {
    func _read_n{dict_ptr: DictAccess*}(index: felt, n: felt, output: felt*) {
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
