// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le

from kakarot.model import model
from utils.utils import Helpers
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.execution_context import ExecutionContext
from kakarot.constants import Constants

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    const GAS_COST_MLOAD = 3;
    const GAS_COST_MSTORE = 3;
    const GAS_COST_PC = 2;
    const GAS_COST_MSIZE = 2;
    const GAS_COST_GAS = 2;

    // @notice MLOAD operation
    // @dev Load word from memory and push to stack.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_load{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x51 - MLOAD") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the word we read.
        let (stack, offset) = Stack.pop(stack);

        with_attr error_message("Kakarot: MemoryOverflow") {
            assert_le(offset.low, Constants.MAX_MEMORY_OFFSET);
        }
        
        //Read word from memory at offset
        let value = Memory.load(self=ctx.memory, offset=offset.low);

        //Push word to the stack
        let stack: model.Stack* = Stack.push(stack, value);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MLOAD);
        return ctx;
    }

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_store{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x52 - MSTORE") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value to store in memory.
        let (stack, offset) = Stack.pop(stack);
        let (stack, value) = Stack.pop(stack);

        with_attr error_message("Kakarot: MemoryOverflow") {
            assert_le(offset.low, Constants.MAX_MEMORY_OFFSET);
        }

        let memory: model.Memory* = Memory.store(self=ctx.memory, element=value, offset=offset.low);

        // Update context stack.
        let ctx = ExecutionContext.update_memory(ctx, memory);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE);
        return ctx;
    }

    // @notice PC operation
    // @dev Get the value of the program counter prior to the increment.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x58 - PC") %}
        let pc = Helpers.to_uint256(ctx.program_counter - 1);

        let stack: model.Stack* = Stack.push(ctx.stack, pc);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_PC);
        return ctx;
    }

    // @notice MSIZE operation
    // @dev Get the value of memory size.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x59 - MSIZE") %}
        let len = Memory.len(ctx.memory);
        let msize = Helpers.to_uint256(len);

        let stack: model.Stack* = Stack.push(ctx.stack, msize);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSIZE);
        return ctx;
    }

    // @notice GAS operation
    // @dev Get the remaining gas after this instruction.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x5a - GAS") %}
        // get remaining gas based 
        let current_remaining_gas : felt = ctx.gas_limit - ctx.gas_used - GAS_COST_GAS;
        let remaining_gas = Helpers.to_uint256(current_remaining_gas);

        let stack: model.Stack* = Stack.push(ctx.stack, remaining_gas);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GAS);
        return ctx;
    }
}
