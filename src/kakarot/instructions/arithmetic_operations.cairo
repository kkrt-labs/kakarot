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

// @title Arithmetic operations opcodes.
// @notice This contract contains the functions to execute for arithemetic operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace ArithmeticOperations
namespace ArithmeticOperations {
    // Define constants.
    const GAS_COST_ADD = 3;

    // @notice 0x00 - ADD
    // @dev Addition operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_add{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x01 - ADD") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: first integer value to add.
        // 1 - b: second integer value to add.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the addition
        let (result) = SafeUint256.add(a, b);

        // Stack output:
        // a + b: integer result of the addition modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_ADD);
        return ctx;
    }
}
