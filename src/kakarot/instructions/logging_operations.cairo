// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
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

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter];
        let topics_len = opcode_number - 0xa0;

        // Pop offset + size.
        let (stack, popped) = Stack.pop_n(ctx.stack, topics_len + 2);
        let offset = popped[0];
        let size = popped[1];

        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + size.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        // Log topics by emitting a starknet event
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let (data: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, size.low, data, offset.low);
        let ctx = ExecutionContext.update_memory(ctx, memory);
        let ctx = ExecutionContext.push_event(ctx, topics_len, popped + 4, size.low, data);

        return ctx;
    }
}
