// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.constants import registry_address
from kakarot.interfaces.interfaces import IRegistry, IEvmContract

// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
// @author @abdelhamidbakhta
// @custom:namespace ExecutionContext
// @custom:model model.ExecutionContext
namespace ExecutionContext {
    // Summary of the execution. Created upon finalization of the execution.
    struct Summary {
        memory: Memory.Summary*,
        stack: Stack.Summary*,
        return_data: felt*,
        return_data_len: felt,
        gas_used: felt,
        starknet_contract_address: felt,
        evm_contract_address: felt,
    }

    // @notice Initialize an empty context to act as a placeholder for root context
    // @return An stopped execution context
    func init_empty() -> model.ExecutionContext* {
        let (root_context) = get_label_location(empty_context);
        let ctx = cast(root_context, model.ExecutionContext*);
        return ctx;

        empty_context:
        dw 0;  // call_context
        dw 0;  // program_counter
        dw 1;  // stopped
        dw 0;  // return_data
        dw 0;  // return_data_len
        dw 0;  // stack
        dw 0;  // memory
        dw 0;  // gas_used
        dw 0;  // gas_limit
        dw 0;  // intrinsic_gas_cost
        dw 0;  // starknet_contract_address
        dw 0;  // evm_contract_address
        dw 0;  // calling_context
        dw 0;  // sub_context
    }

    // @notice Initialize the execution context.
    // @dev set the initial values before executing a piece of code
    // @param call_context The call context.
    // @return The initialized execution context.
    func init(call_context: model.CallContext*) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();
        let (empty_destroy_contract: felt*) = alloc();

        // Define initial program counter
        let initial_pc = 0;
        let gas_used = 0;
        // TODO: Add support for gas limit
        let gas_limit = Constants.TRANSACTION_GAS_LIMIT;

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();
        // Note: calling_context should theoretically take this context as sub_context but this not does really matter
        // so we keep it easier like that.
        let calling_context = init_empty();
        let sub_context = init_empty();

        local ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=call_context,
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            return_data_len=0,
            stack=stack,
            memory=memory,
            gas_used=gas_used,
            gas_limit=gas_limit,
            intrinsic_gas_cost=0,
            starknet_contract_address=0,
            evm_contract_address=0,
            calling_context=calling_context,
            sub_context=sub_context,
            destroy_contracts_len=0,
            destroy_contracts=empty_destroy_contract,
            );
        return ctx;
    }

    // @notice Finalizes the execution context.
    // @return The pointer to the execution Summary.
    func finalize{range_check_ptr}(self: model.ExecutionContext*) -> Summary* {
        alloc_locals;
        let memory_summary = Memory.finalize(self.memory);
        let stack_summary = Stack.finalize(self.stack);

        return new Summary(
            memory=memory_summary,
            stack=stack_summary,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            gas_used=self.gas_used,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            );
    }

    // @notice Initialize the execution context.
    // @dev Initialize the execution context of a specific contract
    // @param address The evm address from which the code will be executed
    // @param calldata_len The calldata length
    // @param calldata The calldata.
    // @return The initialized execution context.
    func init_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: felt,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        calling_context: model.ExecutionContext*,
        return_data_len: felt,
        return_data: felt*,
    ) -> model.ExecutionContext* {
        alloc_locals;

        let (empty_destroy_contract: felt*) = alloc();

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        // Get the starknet address from the given evm address
        let (registry_address_) = registry_address.read();
        let (starknet_contract_address) = IRegistry.get_starknet_contract_address(
            contract_address=registry_address_, evm_contract_address=address
        );

        // Get the bytecode from the Starknet_contract
        let (bytecode_len, bytecode) = IEvmContract.bytecode(
            contract_address=starknet_contract_address
        );
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode, bytecode_len=bytecode_len, calldata=calldata, calldata_len=calldata_len, value=value
            );

        let sub_context = init_empty();

        return new model.ExecutionContext(
            call_context=call_context,
            program_counter=0,
            stopped=FALSE,
            return_data=return_data,
            return_data_len=return_data_len,
            stack=stack,
            memory=memory,
            gas_used=0,
            // TODO: Add support for gas limit
            gas_limit=0,
            intrinsic_gas_cost=0,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=address,
            calling_context=calling_context,
            sub_context=sub_context,
            destroy_contracts_len=0,
            destroy_contracts=empty_destroy_contract,
            );
    }

    // @notice Compute the intrinsic gas cost of the current transaction.
    // @dev Update the given execution context with the intrinsic gas cost.
    // @param self The execution context.
    // @return The updated execution context.
    func compute_intrinsic_gas_cost(self: model.ExecutionContext*) -> model.ExecutionContext* {
        let intrinsic_gas_cost = Constants.TRANSACTION_INTRINSIC_GAS_COST;
        let gas_used = self.gas_used + intrinsic_gas_cost;
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Return whether the current execution context is stopped.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @return TRUE if the execution context is stopped, FALSE otherwise.
    func is_stopped(self: model.ExecutionContext*) -> felt {
        return self.stopped;
    }

    // @notice Return whether the current execution context is root.
    // @dev When the execution context is root, no calling context can be called when this context stops.
    // @param self The pointer to the execution context.
    // @return TRUE if the execution context is root, FALSE otherwise.
    func is_root(self: model.ExecutionContext*) -> felt {
        if (cast(self.calling_context, felt) == 0) {
            return TRUE;
        }
        return FALSE;
    }

    // @notice Return whether the current execution context is a leaf.
    // @dev A leaf context is a context without sub context.
    // @param self The pointer to the execution context.
    // @return TRUE if the execution context is a leaf, FALSE otherwise.
    func is_leaf(self: model.ExecutionContext*) -> felt {
        if (cast(self.sub_context, felt) == 0) {
            return TRUE;
        }
        return FALSE;
    }

    // @notice Stop the current execution context.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func stop(self: model.ExecutionContext*) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Read and return data from bytecode.
    // @dev The data is read from the bytecode from the current program counter.
    // @param self The pointer to the execution context.
    // @param len The size of the data to read.
    // @return The pointer to the updated execution context.
    // @return The data read from the bytecode.
    func read_code(self: model.ExecutionContext*, len: felt) -> (
        self: model.ExecutionContext*, output: felt*
    ) {
        alloc_locals;
        // Get current pc value
        let pc = self.program_counter;
        let (output: felt*) = alloc();
        // Copy code slice
        memcpy(dst=output, src=self.call_context.bytecode + pc, len=len);
        // Move program counter
        let self = ExecutionContext.increment_program_counter(self=self, inc_value=len);
        return (self=self, output=output);
    }

    // @notice Update the stack of the current execution context.
    // @dev The stack is updated with the given stack.
    // @param self The pointer to the execution context.
    // @param stack The pointer to the new stack.
    func update_stack(
        self: model.ExecutionContext*, new_stack: model.Stack*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=new_stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Update the memory of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the new memory.
    func update_memory(
        self: model.ExecutionContext*, new_memory: model.Memory*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=new_memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Update the return data of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the new memory.
    func update_return_data{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        self: model.ExecutionContext*, new_return_data_len: felt, new_return_data: felt*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=new_return_data,
            return_data_len=new_return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Increment the program counter.
    // @dev The program counter is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the program counter with.
    // @return The pointer to the updated execution context.
    func increment_program_counter(
        self: model.ExecutionContext*, inc_value: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Increment the gas used.
    // @dev The gas used is incremented by the given value.
    // @param self The pointer to the execution context.
    // @param inc_value The value to increment the gas used with.
    // @return The pointer to the updated execution context.
    func increment_gas_used(
        self: model.ExecutionContext*, inc_value: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used + inc_value,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Update the child context of the current execution context.
    // @dev The sub_context is updated with the given context.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the child context.
    func update_sub_context(
        self: model.ExecutionContext*, sub_context: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Update the starknet and evm contract addresses.
    // @dev No check is made using the registry for these two addresses being actually linked.
    // @param self The pointer to the execution context.
    // @param starknet_contract_address The starknet_contract_address to use.
    // @param evm_contract_address The evm_contract_address to use.
    // @param memory The pointer to context.
    func update_addresses(
        self: model.ExecutionContext*, starknet_contract_address: felt, evm_contract_address: felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Update the array of contracts to destroy.
    // @param self The pointer to the execution context.
    // @param destroy_contracts_len Array new length.
    // @param destroy_contracts The pointer to the new array of contracts.
    func update_destroy_contracts(
        self: model.ExecutionContext*,
        destroy_contracts_len: felt,
        destroy_contracts: felt*,
        stop: felt,
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=stop,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=destroy_contracts_len,
            destroy_contracts=destroy_contracts,
            );
    }

    // @notice Dump the current execution context.
    // @dev The execution context is dumped to the debug server if `DEBUG` environment variable is set to `True`.
    func dump{range_check_ptr}(self: model.ExecutionContext*) {
        let pc = self.program_counter;
        let stopped = is_stopped(self);

        return ();
    }

    // @notice Update the program counter.
    // @dev The program counter is updated to a given value. This is only ever called by JUMP or JUMPI
    // @param self The pointer to the execution context.
    // @param new_pc_offset The value to update the program counter by.
    // @return The pointer to the updated execution context.
    func update_program_counter{range_check_ptr}(
        self: model.ExecutionContext*, new_pc_offset: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        // Revert if new_value points outside of the code range
        with_attr error_message("Kakarot: new pc target out of range") {
            assert_nn(new_pc_offset);
            assert_le(new_pc_offset, self.call_context.bytecode_len - 1);
        }

        // Revert if new pc_offset points to something other then JUMPDEST
        check_jumpdest(self=self, pc_location=new_pc_offset);

        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            );
    }

    // @notice Check if location is a valid Jump destination
    // @dev Extract the byte that the current pc is pointing to and revert if it is not a JUMPDEST operation.
    // @param self The pointer to the execution context
    // @param pc_location location to check
    func check_jumpdest(self: model.ExecutionContext*, pc_location: felt) {
        alloc_locals;
        let (local output: felt*) = alloc();

        // Copy bytecode slice
        memcpy(dst=output, src=self.call_context.bytecode + pc_location, len=1);

        // Revert if current pc location is not JUMPDEST
        with_attr error_message("Kakarot: JUMPed to pc offset is not JUMPDEST") {
            assert [output] = 0x5b;
        }

        return ();
    }
}
