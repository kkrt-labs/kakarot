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
    func init() -> (stack: model.Stack) {
        alloc_locals;
        let (local elements: Uint256*) = alloc();
        let stack: model.Stack = model.Stack(elements=elements);
        return (stack=stack);
    }

    func raw_len(self: model.Stack) -> (res: felt) {
        let element_size = Uint256.SIZE;
        let (raw_len) = Helpers.get_len(self.elements);
        return (res=raw_len);
    }

    func len(self: model.Stack) -> (res: felt) {
        let element_size = Uint256.SIZE;
        let (raw_len) = Helpers.get_len(self.elements);
        let actual_len = raw_len / 2;
        return (res=actual_len);
    }

    func push{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Stack, element: Uint256
    ) {
        let (stack_len) = Stack.len(self);
        let is_overflow = is_le(Constants.STACK_MAX_DEPTH, stack_len);
        // revert if stack overflow
        with_attr error_message("Zkairvm: StackOverflow") {
            assert is_overflow = FALSE;
        }
        let (raw_len) = Stack.raw_len(self);
        assert [self.elements + raw_len] = element;
        return ();
    }

    func pop(self: model.Stack) -> (element: Uint256) {
        let element = Uint256(0, 0);
        return (element=element);
    }

    func peek(self: model.Stack, index: felt) -> (element: Uint256) {
        let element = Uint256(0, 0);
        return (element=element);
    }
}
