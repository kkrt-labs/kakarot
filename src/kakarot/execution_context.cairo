// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.stack import Stack
from kakarot.constants import Constants

// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
// @author @abdelhamidbakhta
// @custom:namespace ExecutionContext
// @custom:model model.ExecutionContext
namespace ExecutionContext {
    // @notice Initialize the execution context.
    // @param code The code to execute.
    // @param calldata The calldata.
    // @return The initialized execution context.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(code: felt*, code_len: felt, calldata: felt*) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();

        // Define initial program counter
        let initial_pc = 0;
        let gas_used = 0;
        // TODO: Add support for gas limit
        let gas_limit = 0;

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        local ctx: model.ExecutionContext* = new model.ExecutionContext(
            code=code,
            code_len=code_len,
            calldata=calldata,
            calldata_len=Helpers.get_len(calldata),
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            return_data_len=Helpers.get_len(empty_return_data),
            stack=stack,
            memory=memory,
            gas_used=gas_used,
            gas_limit=gas_limit,
            intrinsic_gas_cost=0,
            );
        return ctx;
    }

    // @notice Compute the intrinsic gas cost of the current transaction.
    // @dev Update the given execution context with the intrinsic gas cost.
    // @param self The execution context.
    // @return The updated execution context.
    func compute_intrinsic_gas_cost(self: model.ExecutionContext*) -> model.ExecutionContext* {
        let intrinsic_gas_cost = Constants.TRANSACTION_INTRINSIC_GAS_COST;
        let gas_used = self.gas_used + intrinsic_gas_cost;
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=intrinsic_gas_cost,
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
    func stop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
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
        let (local output: felt*) = alloc();
        // Copy code slice
        memcpy(dst=output, src=self.code + pc, len=len);
        // Move program counter
        let self = ExecutionContext.increment_program_counter(self, len);
        return (self=self, output=output);
    }

    // @notice Update the stack of the current execution context.
    // @dev The stack is updated with the given stack.
    // @param self The pointer to the execution context.
    // @param stack The pointer to the new stack.
    func update_stack{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*, new_stack: model.Stack*) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=new_stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            );
    }

    // @notice Update the memory of the current execution context.
    // @dev The memory is updated with the given memory.
    // @param self The pointer to the execution context.
    // @param memory The pointer to the new memory.
    func update_memory{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*, new_memory: model.Memory*) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=new_memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
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
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
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
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used + inc_value,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            );
    }

    // @notice Dump the current execution context.
    // @dev The execution context is dumped to the debug server if `DEBUG` environment variable is set to `True`.
    func dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.ExecutionContext*) {
        let pc = self.program_counter;
        let stopped = is_stopped(self);
        %{
            import json
            code = cairo_bytes_to_hex(ids.self.code)
            calldata = cairo_bytes_to_hex(ids.self.calldata)
            return_data = cairo_bytes_to_hex(ids.self.return_data)
            json_data = {
                "pc": f"{ids.pc}",
                "stopped": f"{ids.stopped}",
                "return_data": f"{return_data}",
                "gas_used": f"{ids.self.gas_used}",
            }
            json_formatted = json.dumps(json_data, indent=4)
            # print(json_formatted)
            post_debug(json_data)
        %}

        %{
            import logging
            logging.info("===================================")
            logging.info(f"PROGRAM COUNTER:\t{ids.pc}")
            logging.info(f"INTRINSIC GAS:\t\t{ids.self.intrinsic_gas_cost}")
            logging.info(f"GAS USED:\t\t{ids.self.gas_used}")
            logging.info("*************STACK*****************")
        %}
        Stack.dump(self.stack);
        %{
            import logging
            logging.info("***********************************")
            logging.info("===================================")
        %}
        Memory.dump(self.memory);
        %{ print("===================================") %}
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
            assert_le(new_pc_offset, self.code_len - 1);
        }

        // Revert if new pc_offset points to something other then JUMPDEST
        check_jumpdest(self, new_pc_offset);

        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            calldata_len=self.calldata_len,
            program_counter=new_pc_offset,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            intrinsic_gas_cost=self.intrinsic_gas_cost,
            );
    }

    // @notice Check if location is a valid Jump destination
    // @dev The check is done directly on the bytecode.
    // @param self The pointer to the execution context.
    // @param pc_location location to check.
    // @return The pointer to the updated execution context.
    // @return 1 if location is valid, 0 is location is invalid.
    func check_jumpdest(self: model.ExecutionContext*, pc_location: felt) {
        alloc_locals;
        let (local output: felt*) = alloc();

        // Copy code slice
        memcpy(dst=output, src=self.code + pc_location, len=1);

        // Revert if now pc offset is not JUMPDEST
        with_attr error_message("Kakarot: JUMPed to pc offset is not JUMPDEST") {
            assert [output] = 0x5b;
        }

        return ();
    }
}
