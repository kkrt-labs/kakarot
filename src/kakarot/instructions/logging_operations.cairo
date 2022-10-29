// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Logging operations opcodes.
// @notice This file contains the functions to execute for logging operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace LoggingOperations
namespace LoggingOperations {
    // Define constants.
    const GAS_LOG_STATIC = 350;

    // @notice LOG0 operation.
    // @dev Append log record with no topic.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_log_0{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info(f"0xA0 - LOG0")
        %}

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Pop offset + size.
        let (stack, popped) = Stack.pop_n(stack, 2);
        let offset = popped[1];
        let size = popped[0];

        // TODO: Read data from memory (read size bytes starting from offset).
        // TODO: Emit event using emit_event low level function.

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // TODO: compute dynamic gas cost.
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_LOG_STATIC);
        return ctx;
    }
}
