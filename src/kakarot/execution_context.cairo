// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack

// @title ExecutionContext related functions.
// @notice This file contains functions related to the execution context.
// @author @abdelhamidbakhta
// @custom:namespace ExecutionContext
// @custom:model model.ExecutionContext
namespace ExecutionContext {
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
    func stop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            program_counter=self.program_counter,
            stopped=TRUE,
            return_data=self.return_data,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit
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
    func update_stack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext*, new_stack: model.Stack*
    ) -> model.ExecutionContext* {
        return new model.ExecutionContext(
            code=self.code,
            code_len=self.code_len,
            calldata=self.calldata,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            stack=new_stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit
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
            program_counter=self.program_counter + inc_value,
            stopped=self.stopped,
            return_data=self.return_data,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit
            );
    }

    // @notice Dump the current execution context.
    // @dev The execution context is dumped to the debug server if `DEBUG` environment variable is set to `True`.
    func dump(self: model.ExecutionContext*) {
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
            }
            json_formatted = json.dumps(json_data, indent=4)
            # print(json_formatted)
            post_debug(json_data)
        %}
        return ();
    }
}
