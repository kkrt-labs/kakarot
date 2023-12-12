// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE

from kakarot.model import model
from kakarot.evm import EVM
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.errors import Errors

// @title Exchange operations opcodes.
namespace ExchangeOperations {
    // @notice Generic SWAP operation
    // @dev Exchange 1st and i-th stack items
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_swap{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let i = opcode_number - 0x8f;
        Stack.swap_i(i);

        return evm;
    }
}
