// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_le

from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.execution_context import ExecutionContext
from kakarot.constants import Constants

// @title Exchange operations opcodes.
// @notice This contract contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    const GAS_COST_MSTORE = 3;

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_store{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
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
}
