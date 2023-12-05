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
from kakarot.constants import Constants

// @title Duplication operations opcodes.
namespace DuplicationOperations {
    // @notice Generic DUP operation
    // @dev Duplicate the top i-th stack item to the top of the stack.
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext Updated execution context.
    func exec_dup{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter];
        let i = opcode_number - 0x7F;

        let (stack, element) = Stack.peek(ctx.stack, i - 1);
        let stack = Stack.push(stack, element);

        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }
}
