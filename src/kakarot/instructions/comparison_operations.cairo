// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_lt,
    uint256_signed_lt,
    uint256_eq,
    uint256_shl,
    uint256_shr,
    uint256_and,
    uint256_or,
)

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Comparison & Bitwise Logic operations opcodes.
// @notice This file contains the functions to execute for comparison & bitwise logic operations opcodes.
// @author @MentorNotPseudo @abdelhamidbakhta
// @custom:namespace ComparisonOperations
namespace ComparisonOperations {
    // Define constants.
    const GAS_COST_LT = 3;
    const GAS_COST_GT = 3;
    const GAS_COST_SLT = 3;
    const GAS_COST_SGT = 3;
    const GAS_COST_ISZERO = 3;
    const GAS_COST_AND = 3;
    const GAS_COST_OR = 3;
    const GAS_COST_EQ = 3;
    const GAS_COST_SHL = 3;
    const GAS_COST_SHR = 3;

    // @notice 0x10 - LT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_lt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
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
    func exec_gt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
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
    func exec_slt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
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
    func exec_sgt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
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

    // @notice 0x11 - EQ
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_eq{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x14 - EQ") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the comparison
        let (result) = uint256_eq(b, a);

        // Stack output:
        // a == b: 1 if the left side is equal to the right side, 0 otherwise.
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_EQ);
        return ctx;
    }

    // @notice 0x15 - ISZERO
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_iszero{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x15 - ISZERO") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: integer
        let (stack, a) = Stack.pop(stack);

        // a == 0: 1 if a is 0, 0 otherwise.
        let (result) = uint256_eq(a, Uint256(0, 0));

        // Stack output:
        // a == 0: 1 if a is 0, 0 otherwise.
        let stack: model.Stack* = Stack.push(stack, Uint256(result, 0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_ISZERO);
        return ctx;
    }

    // @notice 0x16 - AND
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_and{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x16 - AND") %}

        let stack = ctx.stack;

        // Stack input
        // a: first binary value.
        // b: second binary value.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // a & b: the bitwise AND result.
        let (result) = uint256_and(a, b);

        // Stack output:
        // a & b: the bitwise AND result.
        let stack: model.Stack* = Stack.push(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_AND);
        return ctx;
    }

    // @notice 0x17 - OR
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_or{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x17 - OR") %}

        let stack = ctx.stack;

        // Stack input
        // a: first binary value.
        // b: second binary value.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // a & b: the bitwise AND result.
        let (result) = uint256_or(a, b);

        // Stack output:
        // a & b: the bitwise AND result.
        let stack: model.Stack* = Stack.push(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_OR);
        return ctx;
    }

    // @notice 0x1B - SHL
    // @dev Bitwise operation
    // @custom:since Constantinople
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_shl{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x1B - SHL") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - shift: integer
        // 1 - value: integer
        let (stack, shift) = Stack.pop(stack);
        let (stack, value) = Stack.pop(stack);

        // Left shift `value` by `shift`.
        let (result) = uint256_shl(value, shift);

        // Stack output:
        // The result of the shift operation.
        let stack: model.Stack* = Stack.push(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SHL);
        return ctx;
    }

    // @notice 0x1C - SHR
    // @dev Bitwise operation
    // @custom:since Constantinople
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_shr{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x1C - SHR") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - shift: integer
        // 1 - value: integer
        let (stack, shift) = Stack.pop(stack);
        let (stack, value) = Stack.pop(stack);

        // Right shift `value` by `shift`.
        let (result) = uint256_shr(value, shift);

        // Stack output:
        // The result of the shift operation.
        let stack: model.Stack* = Stack.push(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SHR);
        return ctx;
    }
}
