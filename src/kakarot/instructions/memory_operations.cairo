// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le, uint256_unsigned_div_rem
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.dict import (
    DictAccess,
    dict_new,
    dict_read,
    dict_squash,
    dict_update,
    dict_write,
)
from starkware.cairo.common.registers import get_fp_and_pc

from kakarot.model import model
from utils.utils import Helpers
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.execution_context import ExecutionContext
from kakarot.interfaces.interfaces import IContractAccount

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for memory operations opcodes.
// @author @LucasLvy @abdelhamidbakhta
// @custom:namespace MemoryOperations
namespace MemoryOperations {
    const GAS_COST_MLOAD = 3;
    const GAS_COST_MSTORE = 3;
    const GAS_COST_PC = 2;
    const GAS_COST_MSIZE = 2;
    const GAS_COST_JUMP = 8;
    const GAS_COST_JUMPI = 10;
    const GAS_COST_JUMPDEST = 1;
    const GAS_COST_POP = 2;
    const GAS_COST_MSTORE8 = 3;
    const GAS_COST_SSTORE = 100;
    const GAS_COST_SLOAD = 100;
    const GAS_COST_GAS = 2;

    // @notice MLOAD operation
    // @dev Load word from memory and push to stack.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the word we read.
        let (stack, offset) = Stack.pop(stack);

        // Read word from memory at offset
        let (new_memory, value, cost) = Memory.load(self=ctx.memory, offset=offset.low);

        // Push word to the stack
        let stack: model.Stack* = Stack.push(stack, value);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, new_memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MLOAD + cost);

        return ctx;
    }

    // @notice MSTORE operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value to store in memory.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let value = popped[1];

        let memory: model.Memory* = Memory.store(self=ctx.memory, element=value, offset=offset.low);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE);
        return ctx;
    }

    // @notice PC operation
    // @dev Get the value of the program counter prior to the increment.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @return ExecutionContext Updated execution context.
    func exec_pc{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let pc = Helpers.to_uint256(ctx.program_counter - 1);

        let stack: model.Stack* = Stack.push(ctx.stack, pc);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_PC);
        return ctx;
    }

    // @notice MSIZE operation
    // @dev Get the value of memory size.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_msize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let len = ctx.memory.bytes_len;
        let msize = Helpers.to_uint256(len);

        let stack: model.Stack* = Stack.push(ctx.stack, msize);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSIZE);
        return ctx;
    }

    // @notice JUMP operation
    // @dev The JUMP instruction changes the pc counter. The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 8
    // @custom:stack_consumed_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        let (stack, offset) = Stack.pop(stack);

        // Update pc counter.
        let ctx = ExecutionContext.update_program_counter(ctx, offset.low);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMP);
        return ctx;
    }

    // @notice JUMPI operation
    // @dev Change the pc counter under a provided certain condition.
    //      The new pc target has to be a JUMPDEST opcode.
    // @custom:since Frontier
    // @custom:group Stack Memory and Flow operations.
    // @custom:gas 10
    // @custom:stack_consumed_elements 2
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jumpi{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: offset in the deployed code where execution will continue from
        // 1 - skip_condition: condition that will trigger a jump if not FALSE
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let skip_condition = popped[1];

        // Update pc if skip_jump is anything other then 0

        let (is_condition_valid) = uint256_le(Uint256(1, 0), skip_condition);

        if (is_condition_valid != FALSE) {
            // Update pc counter.
            let ctx = ExecutionContext.update_program_counter(ctx, offset.low);
            // Update context stack.
            let ctx = ExecutionContext.update_stack(ctx, stack);
            // Increment gas used.
            let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPI);
            return ctx;
        }

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPI);
        return ctx;
    }

    // @notice JUMPDEST operation
    // @dev Serves as a check that JUMP or JUMPI was executed correctly. We only update gas used.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_JUMPDEST);

        return ctx;
    }

    // @notice POP operation
    // @dev Pops the first item on the stack (top of the stack).
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_pop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        let (stack, _) = Stack.pop(stack);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_POP);
        return ctx;
    }

    // @notice MSTORE8 operation
    // @dev Save single byte to memory
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_mstore8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - value: value from which the last byte will be extracted and stored in memory.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let value = popped[1];

        // Extract last byte from stack value
        let (_, remainder) = uint256_unsigned_div_rem(value, Uint256(256, 0));
        let (value_pointer: felt*) = alloc();
        assert [value_pointer] = remainder.low;

        // Store byte to memory at offset
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=1, element=value_pointer, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_MSTORE8);
        return ctx;
    }

    // @notice SSTORE operation
    // @dev Save word to storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_sstore{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // This instruction is disallowed when called from a `staticcall` context, which we demark by a read_only attribute
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only = FALSE;
        }

        let stack = ctx.stack;

        // ------- 1. Get starknet address
        let starknet_contract_address: felt = ctx.starknet_contract_address;

        // ----- 2. Pop 2 values: key and value

        // Stack input:
        // 0 - key: key of memory.
        // 1 - value: value for given key.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let key = popped[0];
        let value = popped[1];

        // 3. Call Write storage on contract with starknet address
        with_attr error_message("Contract call failed") {
            let (local prior_value: Uint256) = IContractAccount.storage(
                contract_address=starknet_contract_address, key=key
            );

            IContractAccount.write_storage(
                contract_address=starknet_contract_address, key=key, value=value
            );
        }

        tempvar key_val = new model.KeyValue(key, prior_value);
        let revert_contract_state_dict_end = ctx.revert_contract_state.dict_end;

        let (maybe_written) = dict_read{dict_ptr=revert_contract_state_dict_end}(key=key.low);

        // we only want to track the initial state of a written value relative to the beginning of the execution context, which is the very first write to the dictionary
        // we initialize a default dictionary with the default value as zero.
        // we check if return value of a read is zero to mark whether we want to write the prior value in this case or not.
        if (maybe_written != 0) {
            // if the value is not zero, then we treat it as a pointer to a keyvalue struct,
            // meaning that the prior state was already written, so we do no writing

            // Increment gas used.
            let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SSTORE);
            return ctx;
        } else {
            // otherwise, there has been no write yet for this given context,
            // so this prior is the prior to the entire execution context
            // so we *do* write the keyvalue struct pointer to the dict
            dict_write{dict_ptr=revert_contract_state_dict_end}(
                key=key.low, new_value=cast(key_val, felt)
            );

            let ctx = ExecutionContext.update_revert_contract_state(
                ctx, revert_contract_state_dict_end
            );

            // Increment gas used.
            let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SSTORE);
            return ctx;
        }
    }

    // @notice SLOAD operation
    // @dev Load from storage.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_sload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let stack = ctx.stack;

        // ------- 1. Get starknet address
        let starknet_contract_address: felt = ctx.starknet_contract_address;

        // ----- 2. Pop 1 value: key

        // Stack input:
        // key: key of memory.
        let (stack, local key) = Stack.pop(stack);
        // local value: Uint256;
        // 3. Get the data from storage

        let (local value: Uint256) = IContractAccount.storage(
            contract_address=starknet_contract_address, key=key
        );

        let stack: model.Stack* = Stack.push(stack, value);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SLOAD);
        return ctx;
    }

    // @notice GAS operation
    // @dev Get the amount of available gas, including the corresponding reduction for the cost of this instruction.
    // @custom: since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_gas{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Compute remaining gas.
        let remaining_gas = ctx.gas_limit - ctx.gas_used - GAS_COST_GAS;
        let stack: model.Stack* = Stack.push(ctx.stack, Uint256(remaining_gas, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);

        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GAS);
        return ctx;
    }
}
