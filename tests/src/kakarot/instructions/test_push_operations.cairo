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
from kakarot.instructions.push_operations import PushOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_push_should_push{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) -> (value_len: felt, value: Uint256*) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i + 1, 0xFF);
    let res = PushOperations.exec_push_i(ctx, i);
    let (stack, result) = Stack.peek(res.stack, 0);
    return (1, result);
}
