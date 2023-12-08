// SPDX-License-Identifier: MIT

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from kakarot.model import model
from kakarot.stack import Stack

// @title Duplication operations opcodes.
namespace DuplicationOperations {
    // @notice Generic DUP operation
    // @dev Duplicate the top i-th stack item to the top of the stack.
    // @param evm The pointer to the execution context.
    // @return EVM Updated execution context.
    func exec_dup{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let i = opcode_number - 0x7F;

        let (element) = Stack.peek(i - 1);
        Stack.push(element);

        return evm;
    }
}
