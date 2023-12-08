// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.gas import Gas
from utils.utils import Helpers

// @title Logging operations opcodes.
// @notice This file contains the functions to execute for logging operations opcodes.
namespace LoggingOperations {
    // @notice Generic logging operation
    // @dev Append log record with n topics.
    // @custom:since Frontier
    // @custom:group Logging Operations
    // @param evm The pointer to the execution context
    // @param Topic length.
    // @return EVM The pointer to the execution context.
    func exec_log{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        if (evm.message.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let topics_len = opcode_number - 0xa0;

        // Pop offset + size.
        let (popped) = Stack.pop_n(topics_len + 2);

        // Transform data + safety checks
        local offset = Helpers.uint256_to_felt(popped[0]);
        local size = Helpers.uint256_to_felt(popped[1]);

        // Log topics by emitting a starknet event
        let memory_expansion_cost = Gas.memory_expansion_cost(evm.memory.words_len, offset + size);
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }
        let (data: felt*) = alloc();
        let memory = Memory.load_n(evm.memory, size, data, offset);
        let evm = EVM.update_memory(evm, memory);
        let evm = EVM.push_event(evm, topics_len, popped + 4, size, data);

        return evm;
    }
}
