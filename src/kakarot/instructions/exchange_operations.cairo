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
        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];
        let i = opcode_number - 0x8f;
        let stack = Stack.swap_i(ctx.stack, i);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }
}
