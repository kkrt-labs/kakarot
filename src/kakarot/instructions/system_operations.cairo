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
from kakarot.execution_context import ExecutionContext
from kakarot.library import Kakarot
from kakarot.stack import Stack
from kakarot.memory import Memory

// @title System operations opcodes.
// @notice This file contains the functions to execute for system operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace SystemOperations
namespace SystemOperations {

    // @notice CREATE operation.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_create{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) {
        alloc_locals;

        // Get stack and memory from context
        let stack = ctx.stack;
        let memory = ctx.memory;

        // Stack input:
        // 0 - value: value in wei to send to the new account
        // 1 - offset: byte offset in the memory in bytes (initialization code)
        // 2 - size: byte size to copy (size of initialization code)
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        
        let value = popped[0];
        let offset = popped[1];
        let size = popped[2];

        // Load initialization code from memory
        //let (initialization_code : felt*) = Memory.load_n(memory, size, offset.low);

        //ToDo:
        // -Implement load_n
        // -Deploy contract with constructor execution and usage of value

        // Deploy new contract and execute initialization/constructor code
        let (evm_contract_address: felt, starknet_contract_address: felt) = Kakarot.deploy(size, initialization_code);
        
        // Push evm address of new contract to the stack
        let stack: model.Stack* = Stack.push(stack, evm_contract_address);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ();
    }

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

        let is_total_greater_than_memory_len: felt = is_le(curr_memory_len, total_len);

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
    }(ctx: model.ExecutionContext*) {
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
        let revert_reason_uint256 = Memory.load(memory, offset.low);
        local revert_reason = revert_reason_uint256.low;

        // revert with loaded revert reason short string
        with_attr error_message("Kakarot: Reverted with reason: {revert_reason}") {
            assert TRUE = FALSE;
        }
        return ();
    }
}
