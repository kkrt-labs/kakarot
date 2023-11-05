// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import TRUE

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.errors import Errors

// @title Exchange operations opcodes.
namespace ExchangeOperations {
    // Define constants.
    const GAS_COST_SWAP = 3;

    // @notice Generic SWAP operation
    // @dev Exchange 1st and i-th stack items
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_swap{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + GAS_COST_SWAP - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];
        let i = opcode_number - 0x8f;

        // SWAP_i_ requires i + 1 items in the stack
        let stack_underflow = is_le(ctx.stack.size, i);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = Stack.swap_i(ctx.stack, i);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SWAP);

        return ctx;
    }
}
