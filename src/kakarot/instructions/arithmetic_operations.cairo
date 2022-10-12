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

namespace ArithmeticOperations {
    // 0x00 - ADD
    // Addition operation
    // Since: Frontier
    // Group: Stop and Arithmetic Operations
    func exec_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> (ctx: model.ExecutionContext*) {
        alloc_locals;
        let ctx = [ctx_ptr];
        %{ print("0x01 - ADD") %}
        tempvar range_check_ptr = range_check_ptr;

        let (stack) = ExecutionContext.get_stack(ctx);

        Stack.dump(stack);

        // Stack input:
        // 0 - a: first integer value to add.
        // 1 - b: second integer value to add.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // compute the addition
        let (result) = SafeUint256.add(a, b);
        // let result = Uint256(3, 0);

        // Stack output:
        // a + b: integer result of the addition modulo 2^256
        let stack: model.Stack = Stack.push(stack, result);

        Stack.dump(stack);

        // update context
        // TODO: compute actual values
        let step: model.ExecutionStep = model.ExecutionStep(pc=0, opcode=0, gas=0, stack=stack);
        ExecutionContext.add_step(ctx, step);
        return (ctx=ctx_ptr);
    }
}
