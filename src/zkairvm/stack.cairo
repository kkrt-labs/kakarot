// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt_felt
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from zkairvm.constants import Constants
from zkairvm.model import model
from utils.utils import Helpers

namespace Stack {
    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> model.Stack {
        alloc_locals;
        let (local elements: Uint256*) = alloc();
        let stack: model.Stack = model.Stack(elements=elements, raw_len=0);
        return stack;
    }

    func len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) -> felt {
        let element_size = Uint256.SIZE;
        let actual_len = self.raw_len / element_size;
        return actual_len;
    }

    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, element: Uint256
    ) -> model.Stack {
        alloc_locals;
        let element_size = Uint256.SIZE;
        Stack.check_overlow(self);
        assert [self.elements + self.raw_len] = element;
        let new_stack = model.Stack(elements=self.elements, raw_len=self.raw_len + element_size);
        return new_stack;
    }

    func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) -> Uint256 {
        alloc_locals;
        // TODO: implement me
        let element = Uint256(0, 0);
        return element;
    }

    func peek{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) -> Uint256 {
        alloc_locals;
        Stack.check_underlow(self, stack_index);
        let array_index = Stack.get_array_index(self, stack_index);
        let element: Uint256 = self.elements[array_index];
        return element;
    }

    func check_overlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) {
        let stack_len = Stack.len(self);
        // revert if stack overflow
        with_attr error_message("Zkairvm: StackOverflow") {
            assert_lt_felt(stack_len, Constants.STACK_MAX_DEPTH);
        }
        return ();
    }

    func check_underlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) {
        alloc_locals;
        let stack_len = Stack.len(self);
        with_attr error_message("Zkairvm: StackUnderflow") {
            assert_lt_felt(stack_index, stack_len);
        }
        return ();
    }

    func get_array_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) -> felt {
        let stack_len = Stack.len(self);
        let array_index = stack_len - 1 - stack_index;
        return array_index;
    }

    func print_element_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) {
        let element = Stack.peek(self, stack_index);
        %{
            element_str = cairo_uint256_to_str(ids.element)
            print(f"{element_str}")
        %}
        return ();
    }
}
