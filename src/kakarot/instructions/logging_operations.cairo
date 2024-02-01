// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_not_zero

from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
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
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        if (evm.message.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let topics_len = opcode_number - 0xa0;

        let (popped) = Stack.pop_n(topics_len + 2);

        let offset = popped[0];
        let size = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, size
        );

        let size_cost_low = Gas.LOG_DATA * size.low;
        tempvar size_cost_high = is_not_zero(size.high) * 2 ** 128;
        let topics_cost = Gas.LOG_TOPIC * topics_len;
        let evm = EVM.charge_gas(
            evm, memory_expansion_cost + size_cost_low + size_cost_high + topics_cost
        );
        if (evm.reverted != FALSE) {
            return evm;
        }
        let (data: felt*) = alloc();
        Memory.load_n(size.low, data, offset.low);
        EVM.push_event(evm, topics_len, popped + 4, size.low, data);

        return evm;
    }
}
