// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.bool import FALSE, TRUE

// Internal dependencies
from kakarot.model import model
from kakarot.constants import Constants
from kakarot.errors import Errors
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Push operations opcodes.
namespace PushOperations {
    const BASE_GAS_COST = 2;

    func exec_push{range_check_ptr}(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];
        let i = opcode_number - 0x5f;
        let is_not_push_0 = is_not_zero(i);
        let gas = BASE_GAS_COST + is_not_push_0;

        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + gas - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let ctx = ExecutionContext.increment_gas_used(ctx, gas);

        // Copy code slice
        let pc = ctx.program_counter;
        let out_of_bounds = is_le(ctx.call_context.bytecode_len, pc + i);
        local len = (1 - out_of_bounds) * i + out_of_bounds * (ctx.call_context.bytecode_len - pc);

        let stack_element = Helpers.bytes_i_to_uint256(ctx.call_context.bytecode + pc, len);
        let stack = Stack.push_uint256(ctx.stack, stack_element);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_program_counter(ctx, len);

        return ctx;
    }
}
