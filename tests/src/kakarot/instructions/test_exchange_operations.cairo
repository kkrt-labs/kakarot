// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.exchange_operations import ExchangeOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_swap{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt, stack_len: felt, stack: Uint256*) -> (top: Uint256, swapped: Uint256) {
    let stack_ = TestHelpers.init_stack_with_values(stack_len, stack);
    let (bytecode) = alloc();
    assert [bytecode] = i + 0x8f;
    let ctx = TestHelpers.init_context_with_stack(1, bytecode, stack_);

    // When
    let ctx = ExchangeOperations.exec_swap(ctx);

    // Then
    let stack_ = ctx.stack;
    let (stack_, top) = Stack.peek(stack_, 0);
    let (stack_, swapped) = Stack.peek(stack_, i);
    return ([top], [swapped]);
}
