// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_le_felt

from kakarot.errors import Errors
from kakarot.account import Account
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

        let memory_expansion = Gas.memory_expansion_cost_saturated(
            memory.words_len, [offset], Uint256(32, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            words_len=memory_expansion.new_words_len,
        );

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

        let memory_expansion = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, Uint256(32, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }
        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            words_len=memory_expansion.new_words_len,
        );
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
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
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
            // Return with a PC incremented by one - as JUMP and JUMPi increments
            // are skipped in the main `execute_opcode` loop
            let evm = EVM.increment_program_counter(evm, 1);
            return evm;
        }

        if (offset.high != 0) {
            let (revert_reason_len, revert_reason) = Errors.invalidJumpDestError();
            let evm = EVM.stop(evm, revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
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

        let memory_expansion = Gas.memory_expansion_cost_saturated(
            memory.words_len, offset, Uint256(1, 0)
        );
        let evm = EVM.charge_gas(evm, memory_expansion.cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (_, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));
        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        tempvar memory = new model.Memory(
            word_dict_start=memory.word_dict_start,
            word_dict=memory.word_dict,
            words_len=memory_expansion.new_words_len,
        );
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
        let (popped) = Stack.pop_n(2);
        let key = popped;  // Uint256*
        let new_value = popped + Uint256.SIZE;  // Uint256*

        let is_enough_gasleft = is_le_felt(Gas.CALL_STIPEND + 1, evm.gas_left);
        if (is_enough_gasleft == FALSE) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas(
                evm.gas_left, Gas.CALL_STIPEND
            );
            return new model.EVM(
                message=evm.message,
                return_data_len=revert_reason_len,
                return_data=revert_reason,
                program_counter=evm.program_counter,
                stopped=TRUE,
                gas_left=0,
                gas_refund=evm.gas_refund,
                reverted=Errors.EXCEPTIONAL_HALT,
            );
        }

        // Has to be done BEFORE fetching the current value from the state,
        // otherwise it would warm up the storage slot.
        let is_storage_warm = State.is_storage_warm(evm.message.address.evm, key);
        local gas_cost: felt;
        if (is_storage_warm == FALSE) {
            assert gas_cost = Gas.COLD_SLOAD;
        } else {
            assert gas_cost = 0;
        }

        let account = State.get_account(evm.message.address.evm);
        let original_value = Account.fetch_original_storage(account, key);
        let current_value = State.read_storage(evm.message.address.evm, key);

        let (is_current_original) = uint256_eq(original_value, [current_value]);
        let (is_current_new) = uint256_eq([new_value], [current_value]);
        let (is_original_zero) = uint256_eq(Uint256(0, 0), original_value);

        if (is_current_original * (1 - is_current_new) != FALSE) {
            tempvar gas_cost = gas_cost + (is_original_zero * Gas.STORAGE_SET) + (
                (1 - is_original_zero) * (Gas.STORAGE_UPDATE - Gas.COLD_SLOAD)
            );
        } else {
            tempvar gas_cost = gas_cost + Gas.WARM_ACCESS;
        }

        let evm = EVM.charge_gas(evm, gas_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (is_current_zero) = uint256_eq(Uint256(0, 0), [current_value]);
        let (is_new_zero) = uint256_eq(Uint256(0, 0), [new_value]);

        // storage is being changed and the original value was not zero
        tempvar is_storage_set_changed = (1 - is_current_new) * (1 - is_original_zero);

        // storage is being changed and the original value is the new value
        let (is_new_original) = uint256_eq([new_value], original_value);
        tempvar is_storage_restored = (1 - is_current_new) * is_new_original;

        tempvar gas_refund = is_storage_set_changed * Gas.STORAGE_CLEAR_REFUND * (
            (1 - is_current_zero) * is_new_zero - is_current_zero
        ) + is_storage_restored * (
            is_original_zero * (Gas.STORAGE_SET - Gas.WARM_ACCESS) +
            (1 - is_original_zero) * (Gas.STORAGE_UPDATE - Gas.COLD_SLOAD - Gas.WARM_ACCESS)
        );

        // Operation
        if (evm.message.read_only != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.stateModificationError();
            return new model.EVM(
                message=evm.message,
                return_data_len=revert_reason_len,
                return_data=revert_reason,
                program_counter=evm.program_counter,
                stopped=TRUE,
                gas_left=evm.gas_left,
                gas_refund=evm.gas_refund + gas_refund,
                reverted=Errors.EXCEPTIONAL_HALT,
            );
        }

        State.write_storage(evm.message.address.evm, key, new_value);
        // Return with the updated gas refund
        return new model.EVM(
            message=evm.message,
            return_data_len=evm.return_data_len,
            return_data=evm.return_data,
            program_counter=evm.program_counter,
            stopped=evm.stopped,
            gas_left=evm.gas_left,
            gas_refund=evm.gas_refund + gas_refund,
            reverted=evm.reverted,
        );
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

        // Has to be done BEFORE fetching the current value from the state,
        // otherwise it would warm up the storage slot.
        let is_storage_warm = State.is_storage_warm(evm.message.address.evm, key);
        tempvar gas_cost = is_storage_warm * Gas.WARM_ACCESS + (1 - is_storage_warm) *
            Gas.COLD_SLOAD;
        let evm = EVM.charge_gas(evm, gas_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let value = State.read_storage(evm.message.address.evm, key);
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
