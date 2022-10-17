// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_lt, uint256_signed_lt

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Comparison & Bitwise Logic operations opcodes.
// @notice This contract contains the functions to execute for comparison & bitwise logic operations opcodes.
// @author @MentorNotPseudo @abdelhamidbakhta
// @custom:namespace ComparisonOperations
namespace ComparisonOperations {
    // Define constants.
    const GAS_COST_LT = 3;
    const GAS_COST_GT = 3;
    const GAS_COST_SLT = 3;
    const GAS_COST_SGT = 3;

    // @notice 0x10 - LT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_lt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x10 - LT") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the comparison
        let (result) = uint256_lt(a, b);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_LT);
        return ctx;
    }

    // @notice 0x11 - GT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_gt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x11 - GT") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the comparison
        let (result) = uint256_lt(b, a);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GT);
        return ctx;
    }

    // @notice 0x12 - SLT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_slt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x12 - SLT") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side signed integer.
        // 1 - b: right side signed integer.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the comparison
        let (result) = uint256_signed_lt(a, b);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SLT);
        return ctx;
    }

    // @notice 0x13 - SGT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_sgt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x13 - SGT") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the comparison
        let (result) = uint256_signed_lt(b, a);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SGT);
        return ctx;
    }
}
