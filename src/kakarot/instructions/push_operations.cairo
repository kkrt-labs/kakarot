// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

namespace PushOperations {
    // Generic PUSH operation
    // Place i bytes items on stack
    func exec_push_i{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*, i: felt
    ) -> (ctx: model.ExecutionContext*) {
        alloc_locals;
        let ctx = [ctx_ptr];
        // get stack
        let stack: model.Stack = ExecutionContext.get_stack(ctx);

        // let stack: model.Stack = Stack.init();

        // read i bytes
        let (data) = ExecutionContext.read_code(ctx, i);

        // convert to Uint256
        let (stack_element: Uint256) = Helpers.bytes_to_uint256(data);
        // push to the stack
        let stack: model.Stack = Stack.push(stack, stack_element);

        // update context
        // TODO: compute actual values
        let step: model.ExecutionStep = model.ExecutionStep(pc=0, opcode=0, gas=0, stack=stack);
        ExecutionContext.add_step(ctx, step);

        return (ctx=ctx_ptr);
    }

    // 0x60 - PUSH1
    // Place 1 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> (ctx: model.ExecutionContext*) {
        alloc_locals;
        %{ print("0x60 - PUSH1") %}

        exec_push_i(ctx_ptr, 1);

        return (ctx=ctx_ptr);
    }
}
