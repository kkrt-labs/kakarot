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

// per https://eips.ethereum.org/EIPS/eip-3855,
// we want to check that
// we can push0 1024 times, where all values are zero
// we can push0 1025 times, causing a stackoverlfow
func exec_push_n_times{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(ctx: model.ExecutionContext*, times: felt, value: felt) -> (ctx: model.ExecutionContext*) {
    alloc_locals;

    if (times == 0) {
        return (ctx=ctx);
    }

    let res = PushOperations.exec_push_i(ctx, value);
    return exec_push_n_times(res, times - 1, value);
}

@external
func test__exec_push_should_push_n_times{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(times: felt, value: felt) -> (stack_accesses_len: felt, stack_accesses: felt*, stack_len: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(value + 1, 0xFF);
    let (ctx) = exec_push_n_times(ctx, times, value);
    let stack_summary = Stack.finalize(ctx.stack);
    let stack_accesses_len = stack_summary.squashed_end - stack_summary.squashed_start;
    return (
        stack_accesses_len=stack_accesses_len,
        stack_accesses=stack_summary.squashed_start,
        stack_len=stack_summary.len_16bytes,
    );
}

@external
func test__exec_push_should_raise{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i - 1, 0xFF);
    PushOperations.exec_push_i(ctx, i);

    return ();
}

@external
func test__exec_push_should_push{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt) -> (value: Uint256) {
    alloc_locals;
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_bytecode(i + 1, 0xFF);
    let res = PushOperations.exec_push_i(ctx, i);
    let (stack, result) = Stack.peek(res.stack, 0);
    return (value=result);
}
