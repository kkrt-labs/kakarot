// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le

from kakarot.constants import Constants
from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers

// @title Push operations opcodes.
namespace PushOperations {
    func exec_push{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let opcode_number = [evm.message.bytecode + evm.program_counter];
        let i = opcode_number - 0x5f;

        // Copy code slice
        let pc = evm.program_counter + 1;
        let out_of_bounds = is_le(evm.message.bytecode_len, pc + i);
        local len = (1 - out_of_bounds) * i + out_of_bounds * (evm.message.bytecode_len - pc);

        let stack_element = Helpers.bytes_big_endian_to_uint256(len, evm.message.bytecode + pc);
        Stack.push_uint256(stack_element);

        let evm = EVM.increment_program_counter(evm, len);

        return evm;
    }
}
