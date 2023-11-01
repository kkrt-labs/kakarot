// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.stop_and_arithmetic_operations import StopAndArithmeticOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_stop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);
    assert ctx.stopped = FALSE;

    let stopped_ctx = StopAndArithmeticOperations.exec_stop(ctx);

    assert stopped_ctx.stopped = TRUE;
    assert stopped_ctx.return_data_len = 0;

    return ();
}

@external
func test__exec_arithmetic_operation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(opcode: felt, stack_len: felt, stack: Uint256*, expected_result: Uint256) {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert [bytecode] = opcode;
    let stack_ = Stack.init();

    let stack_ = Stack.push_uint256(stack_, stack[2]);
    let stack_ = Stack.push_uint256(stack_, stack[1]);
    let stack_ = Stack.push_uint256(stack_, stack[0]);
    let ctx = TestHelpers.init_context_with_stack(1, bytecode, stack_);
    let ctx = ExecutionContext.increment_program_counter(ctx, 1);

    // When
    let ctx = StopAndArithmeticOperations.exec_arithmetic_operation(ctx);

    // Then
    let (_, result) = Stack.peek(ctx.stack, 0);
    assert result[0] = expected_result;
    return ();
}
