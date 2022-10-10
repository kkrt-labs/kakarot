// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from zkairvm.constants import Constants
from zkairvm.model import model
from utils.utils import Helpers

namespace Stack {
    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        stack: model.Stack
    ) {
        alloc_locals;
        let (local elements: Uint256*) = alloc();
        let stack: model.Stack = model.Stack(elements=elements);
        return (stack=stack);
    }

    func raw_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) -> (res: felt) {
        let element_size = Uint256.SIZE;
        let (raw_len) = Helpers.get_len(self.elements);
        return (res=raw_len);
    }

    func len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) -> (res: felt) {
        let element_size = Uint256.SIZE;
        let (raw_len) = Helpers.get_len(self.elements);
        let actual_len = raw_len / 2;
        return (res=actual_len);
    }

    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, element: Uint256
    ) {
        alloc_locals;
        Stack.check_overlow(self);
        let (stack_len) = Stack.len(self);
        let (raw_len) = Stack.raw_len(self);
        assert [self.elements + raw_len] = element;
        return ();
    }

    func pop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) -> (element: Uint256) {
        alloc_locals;
        let element = Uint256(0, 0);
        return (element=element);
    }

    func peek{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) -> (element: Uint256) {
        alloc_locals;
        Stack.check_underlow(self, stack_index);
        let (array_index) = Stack.get_array_index(self, stack_index);
        let element: Uint256 = self.elements[array_index];
        return (element=element);
    }

    func check_overlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack
    ) {
        let (stack_len) = Stack.len(self);
        let is_overflow = is_le(Constants.STACK_MAX_DEPTH, stack_len);
        // revert if stack overflow
        with_attr error_message("Zkairvm: StackOverflow") {
            assert is_overflow = FALSE;
        }
        return ();
    }

    func check_underlow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) {
        alloc_locals;
        let (stack_len) = Stack.len(self);
        let is_underflow = is_le(stack_len, stack_index);
        with_attr error_message("Zkairvm: StackUnderflow") {
            assert is_underflow = FALSE;
        }
        return ();
    }

    func get_array_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) -> (array_index: felt) {
        let (stack_len) = Stack.len(self);
        let array_index = stack_len - 1 - stack_index;
        return (array_index=array_index);
    }

    func print_element_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, stack_index: felt
    ) {
        let (element) = Stack.peek(self, stack_index);
        let element_low = element.low;
        let element_high = element.high;
        %{
            print(f"low: {ids.element_low}")    
            print(f"high: {ids.element_high}")
        %}
        return ();
    }
}
