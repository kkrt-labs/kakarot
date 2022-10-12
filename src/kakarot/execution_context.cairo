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

namespace ExecutionContext {
    func is_stopped(self: model.ExecutionContext) -> (stopped: felt) {
        return (stopped=self.stopped);
    }

    func stop(self: model.ExecutionContext*) -> (self: model.ExecutionContext*) {
        alloc_locals;
        let ctx = [self];
        local self_out: model.ExecutionContext* = new model.ExecutionContext(
            code=ctx.code,
            code_len=ctx.code_len,
            calldata=ctx.calldata,
            program_counter=ctx.program_counter,
            stopped=TRUE,
            return_data=ctx.return_data,
            steps=ctx.steps
            );
        return (self=self_out);
    }

    func get_number_of_steps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext
    ) -> (number_of_steps: felt) {
        let (number_of_steps) = Helpers.get_number_of_elements(
            self.steps, model.ExecutionStep.SIZE
        );
        return (number_of_steps=number_of_steps);
    }

    func add_step{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext, step: model.ExecutionStep
    ) {
        alloc_locals;
        let (len) = ExecutionContext.get_number_of_steps(self);
        let raw_len = len * model.ExecutionStep.SIZE;
        assert [self.steps + raw_len] = step;
        return ();
    }

    func get_stack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext
    ) -> (stack: model.Stack) {
        alloc_locals;
        local stack: model.Stack;
        let (number_of_steps) = ExecutionContext.get_number_of_steps(self);

        let has_steps = is_not_zero(number_of_steps);
        if (has_steps == TRUE) {
            let last_step = self.steps[number_of_steps - 1];
            assert stack = last_step.stack;
            return (stack=stack);
        } else {
            let initial_stack = Stack.init();
            assert stack = initial_stack;
            return (stack=stack);
        }
    }

    func read_code(self: model.ExecutionContext*, len: felt) -> (
        self: model.ExecutionContext*, output: felt*
    ) {
        alloc_locals;
        let ctx = [self];
        // get current pc value
        let pc = ctx.program_counter;
        let (local output: felt*) = alloc();
        // copy code slice
        memcpy(dst=output, src=self.code + pc, len=len);
        // move program counter
        let (self_out) = ExecutionContext.increment_program_counter(self, len);
        return (self=self_out, output=output);
    }

    func increment_program_counter(self: model.ExecutionContext*, inc_value: felt) -> (
        self: model.ExecutionContext*
    ) {
        alloc_locals;
        let ctx = [self];
        let previous_program_counter = ctx.program_counter;
        let new_program_counter = previous_program_counter + inc_value;
        local self_out: model.ExecutionContext* = new model.ExecutionContext(
            code=ctx.code,
            code_len=ctx.code_len,
            calldata=ctx.calldata,
            program_counter=new_program_counter,
            stopped=ctx.stopped,
            return_data=ctx.return_data,
            steps=ctx.steps
            );
        return (self=self_out);
    }

    func dump(self: model.ExecutionContext) {
        let pc = self.program_counter;
        let (stopped) = is_stopped(self);
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
