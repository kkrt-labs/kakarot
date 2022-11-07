// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

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
    // @custom:stack_consumed_elements 0
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
        %{
            import logging
            logging.info("0xF3 - RETURN")
        %}

        let (local new_return_data: felt*) = alloc();
        let (local new_memory: model.Memory*) = alloc();
        let (stack, offset) = Stack.pop(stack);
        let (stack, size) = Stack.pop(stack);
        let curr_memory_len: felt = ctx.memory.bytes_len;
        let total_len: felt = offset.low + size.low;
        // TODO check in which multiple of 32 bytes it should be.
        // Pad if offset + size > memory_len pad n
        if (memory.bytes_len == 0) {
            Helpers.fill(arr=memory.bytes, value=0, length=32);
        }

        memcpy(dst=new_return_data, src=ctx.memory.bytes + offset.low, len=size.low);

        // Pad if offset + size > memory_len pad n

        let is_total_greater_than_memory_len: felt = is_le_felt(curr_memory_len, total_len);

        if (is_total_greater_than_memory_len == 1) {
            local diff = total_len - curr_memory_len;
            Helpers.fill(arr=new_return_data + curr_memory_len, value=0, length=diff);
        }

        // TODO if memory.bytes_len == 0 needs a different approach
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // TODO: GAS IMPLEMENTATION

        return ExecutionContext.update_return_data(
            ctx, new_return_data_len=size.low, new_return_data=new_return_data
        );
    }
}
