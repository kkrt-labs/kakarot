// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import emit_event
from starkware.cairo.common.bool import FALSE

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory

// @title Logging operations opcodes.
// @notice This file contains the functions to execute for logging operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace LoggingOperations
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
    func exec_log_i{syscall_ptr: felt*, range_check_ptr}(
        ctx: model.ExecutionContext*, topics_len: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        // This instruction is disallowed when called from a `staticcall` context, which we demark by a read_only attribute
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only = FALSE;
        }

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Pop offset + size.
        let (stack, popped) = Stack.pop_n(stack, topics_len + 2);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let offset = popped[0];
        let size = popped[1];

        // Transform data + safety checks
        let actual_size = Helpers.uint256_to_felt(size);
        let actual_offset = Helpers.uint256_to_felt(offset);

        // Log topics by emitting a starknet event
        let (data: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=actual_size, element=data, offset=actual_offset
        );

        let ctx = ExecutionContext.add_event_to_emit(
            self=ctx,
            event_keys_len=topics_len * 2,
            event_keys=popped + 4,
            event_data_len=actual_size,
            event_data=data,
        );

        // Update context stack.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, gas_cost + GAS_LOG_STATIC);
        return ctx;
    }

    // @notice LOG0 operation.
    // @dev Append log record with no topic.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log_0{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_log_i(ctx, 0);
        return ctx;
    }

    // @notice LOG1 operation.
    // @dev Append log record with 1 topic.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log_1{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_log_i(ctx, 1);
        return ctx;
    }

    // @notice LOG2 operation.
    // @dev Append log record with 2 topics.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log_2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_log_i(ctx, 2);
        return ctx;
    }

    // @notice LOG3 operation.
    // @dev Append log record with 3 topics.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log_3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_log_i(ctx, 3);
        return ctx;
    }

    // @notice LOG4 operation.
    // @dev Append log record with 4 topics.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_log_4{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_log_i(ctx, 4);
        return ctx;
    }
}

namespace LoggingHelper {
    func _finalize_loop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(events_len: felt, events: model.Event*) -> felt* {
        alloc_locals;

        if (events_len == 0) {
            return (events);
        }

        let event: model.Event = [events];

        emit_event(
            keys_len=event.keys_len, keys=event.keys, data_len=event.data_len, data=event.data
        );
        // we maintain the semantics of one event struct involves iterating a full event struct size recursively
        return _finalize_loop(events_len - 1, events + 1 * model.Event.SIZE);
    }

    // @notice helper for log family opcodes.
    // @notice emits all registered events when a calling context is finalized
    // @return The pointer to the updated execution_context.
    func finalize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        _finalize_loop(ctx.events_len, ctx.events);

        // TODO: return a considered execution context
        return ctx;
    }
}
