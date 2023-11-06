// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import emit_event
from starkware.cairo.common.math_cmp import is_le

// Internal dependencies
from kakarot.errors import Errors
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.utils import Helpers

// @title Logging operations opcodes.
// @notice This file contains the functions to execute for logging operations opcodes.
namespace LoggingOperations {
    // Define constants.
    const GAS_LOG_STATIC = 350;

    // @notice Generic logging operation
    // @dev Append log record with n topics.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context
    // @param Topic length.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.call_context.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + GAS_LOG_STATIC - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];
        let topics_len = opcode_number - 0xa0;

        let stack_underflow = is_le(ctx.stack.size, topics_len + 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Pop offset + size.
        let (stack, popped) = Stack.pop_n(stack, topics_len + 2);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Transform data + safety checks
        let size = Helpers.uint256_to_felt(popped[1]);
        let offset = Helpers.uint256_to_felt(popped[0]);

        // Log topics by emitting a starknet event
        let (data: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=size, element=data, offset=offset
        );

        let ctx = ExecutionContext.push_event(
            self=ctx, topics_len=topics_len, topics=popped + 4, data_len=size, data=data
        );

        // Update context stack.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, gas_cost + GAS_LOG_STATIC);
        return ctx;
    }
}
