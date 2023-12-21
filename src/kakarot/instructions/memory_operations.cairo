// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_unsigned_div_rem

from kakarot.errors import Errors
from kakarot.evm import EVM
from kakarot.gas import Gas
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from utils.utils import Helpers

namespace MemoryOperations {
    func exec_mload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (offset) = Stack.pop();

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, [offset], Uint256(32, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let value = Memory.load(offset.low);
        Stack.push_uint256(value);

        return evm;
    }

    func exec_mstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let value = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, Uint256(32, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }
        Memory.store(value, offset.low);

        return evm;
    }

    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(evm.program_counter);
        return evm;
    }

    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(memory.words_len * 32);
        return evm;
    }

    func exec_jump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        let (offset) = Stack.pop();

        if (offset.high != 0) {
            let (revert_reason_len, revert_reason) = Errors.invalidJumpDestError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        let evm = EVM.jump(evm, offset.low);
        return evm;
    }

    func exec_jumpi{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let skip_condition = popped[1];

        // If skip_condition is 0, then don't jump
        let (skip_condition_is_zero) = uint256_eq(Uint256(0, 0), skip_condition);
        if (skip_condition_is_zero != FALSE) {
            return evm;
        }

        if (offset.high != 0) {
            let (revert_reason_len, revert_reason) = Errors.invalidJumpDestError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, TRUE);
            return evm;
        }

        let evm = EVM.jump(evm, offset.low);
        return evm;
    }

    func exec_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        return evm;
    }

    func exec_pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.pop();

        return evm;
    }

    func exec_mstore8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let value = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, Uint256(1, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (_, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));
        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        Memory.store_n(1, value_pointer, offset.low);

        return evm;
    }

    func exec_sstore{
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

        let (popped) = Stack.pop_n(2);

        let key = popped;  // Uint256*
        let value = popped + Uint256.SIZE;  // Uint256*
        State.write_storage(evm.message.address, key, value);
        return evm;
    }

    func exec_sload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (key) = Stack.pop();
        let value = State.read_storage(evm.message.address, key);
        Stack.push(value);
        return evm;
    }

    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(evm.gas_left);

        return evm;
    }
}
