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

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    // @notice MLOAD operation
    // @dev Load word from memory and push to stack.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_mload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (offset_uint256) = Stack.pop();
        let offset = Helpers.uint256_to_felt([offset_uint256]);

        let memory_expansion_cost = Gas.memory_expansion_cost(evm.memory.words_len, offset + 32);
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (memory, value) = Memory.load(evm.memory, offset);
        Stack.push_uint256(value);

        let evm = EVM.update_memory(evm, memory);

        return evm;
    }

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_mstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let value = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost(
            evm.memory.words_len, offset.low + 32
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }
        let memory = Memory.store(self=evm.memory, element=value, offset=offset.low);
        let evm = EVM.update_memory(evm, memory);

        return evm;
    }

    // @notice PC operation
    // @dev Get the value of the program counter prior to the increment.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return EVM Updated execution context.
    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(evm.program_counter);
        return evm;
    }

    // @notice MSIZE operation
    // @dev Get the value of memory size.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(evm.memory.words_len * 32);
        return evm;
    }

    // @notice JUMP operation
    // @dev The JUMP instruction changes the pc counter. The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 8
    // @custom:stack_consumed_elements 1
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_jump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        let (offset) = Stack.pop();
        let evm = EVM.jump(evm, offset.low);
        return evm;
    }

    // @notice JUMPI operation
    // @dev Change the pc counter under a provided certain condition.
    //      The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 10
    // @custom:stack_consumed_elements 2
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_jumpi{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
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

        let evm = EVM.jump(evm, offset.low);
        return evm;
    }

    // @notice JUMPDEST operation
    // @dev Serves as a check that JUMP or JUMPI was executed correctly.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;
        return evm;
    }

    // @notice POP operation
    // @dev Pops the first item on the stack (top of the stack).
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.pop();

        return evm;
    }

    // @notice MSTORE8 operation
    // @dev Save single byte to memory
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_mstore8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let value = popped[1];

        // Extract last byte from stack value
        let (_, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));
        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        // Store byte to memory at offset
        let memory_expansion_cost = Gas.memory_expansion_cost(evm.memory.words_len, offset.low + 1);
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }
        let memory: model.Memory* = Memory.store_n(
            self=evm.memory, element_len=1, element=value_pointer, offset=offset.low
        );
        let evm = EVM.update_memory(evm, memory);

        return evm;
    }

    // @notice SSTORE operation
    // @dev Save word to storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_sstore{
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

        let (popped) = Stack.pop_n(2);

        let key = popped;  // Uint256*
        let value = popped + Uint256.SIZE;  // Uint256*
        let state = State.write_storage(evm.state, evm.message.address, key, value);
        let evm = EVM.update_state(evm, state);
        return evm;
    }

    // @notice SLOAD operation
    // @dev Load from storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_sload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (key) = Stack.pop();
        let (state, value) = State.read_storage(evm.state, evm.message.address, key);
        Stack.push(value);
        let evm = EVM.update_state(evm, state);
        return evm;
    }

    // @notice GAS operation
    // @dev Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param evm The pointer to the execution context
    // @return EVM Updated execution context.
    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        Stack.push_uint128(evm.gas_left);

        return evm;
    }
}
