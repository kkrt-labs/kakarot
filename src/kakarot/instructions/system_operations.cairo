// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory

// @title System operations opcodes.
// @notice This file contains the functions to execute for system operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace SystemOperations
namespace SystemOperations {
    // @notice INVALID operation.
    // @dev Designated invalid instruction.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_invalid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        with_attr error_message("Kakarot: 0xFE: Invalid Opcode") {
            assert TRUE = FALSE;
        }
        // TODO: map the concept of consuming all the gas given to the context

        return ctx;
    }

    // @notice RETURN operation.
    // @dev Designated invalid instruction.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return The pointer to the updated execution context.
    func exec_return{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let stack = ctx.stack;
        let memory = ctx.memory;
        let (stack, offset) = Stack.pop(stack);
        let (stack, size) = Stack.pop(stack);
        let curr_memory_len: felt = ctx.memory.bytes_len;
        let total_len: felt = offset.low + size.low;
        // TODO check in which multiple of 32 bytes it should be.
        let memory = Memory.load_n(
            self=memory, element_len=size.low, element=ctx.return_data, offset=offset.low
        );

        // Pad if offset + size > memory_len pad n

        let is_total_greater_than_memory_len: felt = is_le(curr_memory_len, total_len);

        if (is_total_greater_than_memory_len != FALSE) {
            local diff = total_len - curr_memory_len;
            Helpers.fill(arr_len=diff, arr=ctx.return_data + curr_memory_len, value=0);
        }

        // TODO if memory.bytes_len == 0 needs a different approach
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // TODO: GAS IMPLEMENTATION

        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        let ctx = ExecutionContext.update_return_data(
            // Note: only new data_len needs to be updated indeed.
            ctx, new_return_data_len=size.low, new_return_data=ctx.return_data
        );
        let ctx = ExecutionContext.stop(ctx);
        return ctx;
    }

    // @notice REVERT operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return The pointer to the updated execution context.
    func exec_revert{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack and memory from context
        let stack = ctx.stack;
        let memory = ctx.memory;

        // Stack input:
        // 0 - size: byte size to copy
        // 1 - offset: byte offset in the memory in bytes
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        // TODO: implement loading of the revert reason based on size value,
        // currently limited by short string size
        let size = popped[0];
        let offset = popped[1];

        // Load revert reason from offset
        let (memory, revert_reason_uint256) = Memory.load(memory, offset.low);
        local revert_reason = revert_reason_uint256.low;

        // revert with loaded revert reason short string
        with_attr error_message("Kakarot: Reverted with reason: {revert_reason}") {
            assert TRUE = FALSE;
        }
        // TODO: this is never reached, raising with cairo prevent from implementing a true REVERT
        // TODO: that still returns some data. This is especially problematic for sub contexts.
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        return ctx;
    }

    // @notice CALL operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return The pointer to the sub context.
    func exec_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=7);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let gas = 2 ** 128 * popped[0].high + popped[0].low;
        let address = 2 ** 128 * popped[1].high + popped[1].low;
        let value = 2 ** 128 * popped[2].high + popped[2].low;
        let args_offset = 2 ** 128 * popped[3].high + popped[3].low;
        let args_size = 2 ** 128 * popped[4].high + popped[4].low;
        let ret_offset = 2 ** 128 * popped[5].high + popped[5].low;
        let ret_size = 2 ** 128 * popped[6].high + popped[6].low;
        // Note: We store the offset here because we can't pre-allocate a memory segment in cairo
        // During teardown we update the memory using this offset
        let return_data: felt* = alloc();
        assert [return_data] = ret_offset;

        // Load calldata from Memory
        let (calldata: felt*) = alloc();
        let memory = Memory.load_n(
            self=ctx.memory, element_len=args_size, element=calldata, offset=args_offset
        );
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Prepare execution sub context
        // TODO: use gas_limit when init_at_address is updated
        let sub_ctx = ExecutionContext.init_at_address(
            address=address,
            calldata_len=args_size,
            calldata=calldata,
            value=value,
            parent_context=ctx,
            return_data_len=ret_size,
            return_data=return_data,
        );

        return sub_ctx;
    }
}
