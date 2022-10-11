// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers
from zkairvm.model import model
from zkairvm.stack import Stack

namespace ExecutionContext {
    func get_pc(self: model.ExecutionContext) -> (pc: felt) {
        alloc_locals;
        let (pc) = Helpers.get_last(self.pc);
        return (pc=pc);
    }

    func set_pc(self: model.ExecutionContext, pc: felt) {
        let (pc_len) = Helpers.get_len(self.pc);
        assert [self.pc + pc_len] = pc;
        return ();
    }

    func inc_pc(self: model.ExecutionContext, inc_value: felt) {
        let (pc) = get_pc(self);
        set_pc(self, pc + inc_value);
        return ();
    }

    func is_stopped(self: model.ExecutionContext) -> (stopped: felt) {
        let (stopped) = Helpers.has_entries(self.stopped);
        return (stopped=stopped);
    }

    func stop(self: model.ExecutionContext) {
        assert [self.stopped] = TRUE;
        return ();
    }

    func get_last_step{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.ExecutionContext
    ) -> (step: model.ExecutionStep) {
        alloc_locals;
        local step: model.ExecutionStep;
        %{
            if py_has_entries(ids.self.steps):
                last_idx = py_get_len(ids.self.steps) - 1
                ids.step = memory.get(ids.self.steps + last_idx)
        %}
        return (step=step);
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
        let (len) = Helpers.get_len(self.steps);
        assert [self.steps + len] = step;
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
            let (last_step) = ExecutionContext.get_last_step(self);
            assert stack = last_step.stack;
            return (stack=stack);
        } else {
            let initial_stack = Stack.init();
            assert stack = initial_stack;
            return (stack=stack);
        }
    }

    func dump(self: model.ExecutionContext) {
        let (pc) = get_pc(self);
        let (stopped) = is_stopped(self);
        %{
            code = cairo_bytes_to_hex(ids.self.code)
            calldata = cairo_bytes_to_hex(ids.self.calldata)
            return_data = cairo_bytes_to_hex(ids.self.return_data)
            json = {
                "pc": f"{ids.pc}",
                "stopped": f"{ids.stopped}",
                "return_data": f"{return_data}",
            }
            post_debug(json)
        %}
        return ();
    }
}
