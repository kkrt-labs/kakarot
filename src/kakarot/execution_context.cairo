// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.constants import registry_address
from kakarot.interfaces.interfaces import IRegistry, IEvmContract

// Felt Packing Libraries
from starkware.cairo.common.math import unsigned_div_rem
from utils.bit_functions import get_byte_in_array, get_uint256_in_array
from starkware.cairo.common.uint256 import Uint256

// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
// @author @abdelhamidbakhta
// @custom:namespace ExecutionContext
// @custom:model model.ExecutionContext
namespace ExecutionContext {
    // @notice Initialize the execution context.
    // @dev set the initial values before executing a piece of code
    // @param call_context The call context.
    // @return The initialized execution context.
    func init(call_context: model.CallContext*) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();

        // Define initial program counter
        let initial_pc = 0;
        let gas_used = 0;
        // TODO: Add support for gas limit
        let gas_limit = Constants.TRANSACTION_GAS_LIMIT;

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        // 1. Evm address
        // 2. Get starknet Address
        // 3. Get the constant of Evm address mappings

        local ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=call_context,
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            return_data_len=0,
            original_return_data_len=0,
            stack=stack,
            memory=memory,
            gas_used=gas_used,
            gas_limit=gas_limit,
            intrinsic_gas_cost=0,
            starknet_contract_address=0,
            evm_contract_address=0,
            );
        return ctx;
    }

    // @notice Initialize the execution context.
    // @dev Initialize the execution context of a specific contract
    // @param address The evm address from which the code will be executed
    // @param calldata The calldata.
    // @return The initialized execution context.
    func init_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, calldata: felt*, calldata_len: felt,original_calldata_len:felt, value: felt) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();

        // Define initial program counter
        let initial_pc = 0;
        let gas_used = 0;
        // TODO: Add support for gas limit
        let gas_limit = 0;

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        // Get the starknet address from the given evm address
        let (registry_address_) = registry_address.read();
        let (starknet_contract_address) = IRegistry.get_starknet_contract_address(
            contract_address=registry_address_, evm_contract_address=address
        );

        // Get the bytecode from the Starknet_contract
        let (bytecode_len, bytecode, original_bytecode_len) = IEvmContract.bytecode(
            contract_address=starknet_contract_address
        );
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode, bytecode_len=bytecode_len,original_bytecode_len=original_bytecode_len, calldata=calldata, calldata_len=calldata_len,original_calldata_len=original_calldata_len, value=value
            );

        return new model.ExecutionContext(
            call_context=call_context,
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            return_data_len=0,
            original_return_data_len=0,
            stack=stack,
            memory=memory,
            gas_used=gas_used,
            gas_limit=gas_limit,
            intrinsic_gas_cost=0,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=address,
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
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            );
    }

    // @notice Return whether the current execution context is stopped.
    // @dev When the execution context is stopped, no more instructions can be executed.
    // @param self The pointer to the execution context.
    // @return TRUE if the execution context is stopped, FALSE otherwise.
    func is_stopped(self: model.ExecutionContext*) -> felt {
        return self.stopped;
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
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            );
    }

    // @notice Read and return data from bytecode.
    // @dev The data is read from the bytecode from the current program counter.
    // @param self The pointer to the execution context.
    // @param len The size of the data to read.
    // @return The pointer to the updated execution context.
    // @return The data read from the bytecode.
    func read_code{ syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*}(self: model.ExecutionContext*, len: felt) -> (
        self: model.ExecutionContext*, stack_element: Uint256
    ) {
        alloc_locals;
        // Get current pc value
        let pc = self.program_counter;

        // let (output: felt*) = alloc();
        // // Copy code slice
        // memcpy(dst=output, src=self.call_context.bytecode + pc, len=len);

        // Get Uint256 of 31Bytes felt array
        let stack_element: Uint256 = get_uint256_in_array(offset = pc, code_len=self.call_context.bytecode_len, code = self.call_context.bytecode, len=len);

        // Move program counter
        let self = ExecutionContext.increment_program_counter(self=self, inc_value=len);
        return (self=self, stack_element=stack_element);
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
            original_return_data_len=self.original_return_data_len,            
            stack=new_stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
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
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=new_memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
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
        self: model.ExecutionContext*, new_return_data_len: felt, new_return_data: felt*, original_return_data_len:felt
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=new_return_data,
            return_data_len=new_return_data_len,
            original_return_data_len=original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
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
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
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
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used + inc_value,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
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
    func update_program_counter{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        self: model.ExecutionContext*, new_pc_offset: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        // Revert if new_value points outside of the code range
        with_attr error_message("Kakarot: new pc target out of range") {
            assert_nn(new_pc_offset);
            assert_le(new_pc_offset, self.call_context.original_bytecode_len - 1);
        }

        // Revert if new pc_offset points to something other then JUMPDEST
        check_jumpdest(self=self, pc_location=new_pc_offset);

        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            original_return_data_len=self.original_return_data_len,            
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            starknet_contract_address=self.starknet_contract_address,
            evm_contract_address=self.evm_contract_address,
            );
    }

    // @notice Check if location is a valid Jump destination
    // @dev Extract the byte that the current pc is pointing to and revert if it is not a JUMPDEST operation.
    // @param self The pointer to the execution context
    // @param pc_location location to check
    func check_jumpdest{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*, pc_location: felt) {
        alloc_locals;
        // let (local output: felt*) = alloc();

        // Copy bytecode slice
        let (res, rem) = unsigned_div_rem(pc_location,31);
        let value : felt = [self.call_context.bytecode + res];
        let output : felt = get_byte_in_array(offset=rem,felt_packed_code=value, return_byte_length=1);

        // Revert if current pc location is not JUMPDEST
        with_attr error_message("Kakarot: JUMPed to pc offset is not JUMPDEST") {
            assert output = 0x5b;
        }

        return ();
    }
}
