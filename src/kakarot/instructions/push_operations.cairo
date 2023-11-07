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
    func exec_push{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];
        let i = opcode_number - 0x5f;

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
