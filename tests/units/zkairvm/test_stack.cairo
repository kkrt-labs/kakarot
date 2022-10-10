// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from zkairvm.model import model
from zkairvm.stack import Stack

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

@external
func test_stack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Helpers.setup_python_defs();

    let stack: model.Stack = Stack.init();
    let stack: model.Stack = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack = Stack.push(stack, Uint256(3, 0));

    let len = Stack.len(stack);
    assert len = 3;

    Stack.print_element_at(stack, 0);
    Stack.print_element_at(stack, 1);
    Stack.print_element_at(stack, 2);

    return ();
}

@external
func test_stack_underflow{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Helpers.setup_python_defs();

    let stack: model.Stack = Stack.init();
    Stack.push(stack, Uint256(1, 0));

    %{ expect_revert("TRANSACTION_FAILED", "Zkairvm: StackUnderflow") %}
    Stack.peek(stack, 1);
    return ();
}
