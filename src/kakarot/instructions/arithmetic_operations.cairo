// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_signed_div_rem, uint256_le, uint256_eq

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Arithmetic operations opcodes.
// @notice This contract contains the functions to execute for arithmetic operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace ArithmeticOperations
namespace ArithmeticOperations {
    // Define constants.
    const GAS_COST_ADD = 3;
    const GAS_COST_MUL = 5;
    const GAS_COST_SUB = 3;
    const GAS_COST_DIV = 5;
    const GAS_COST_SDIV = 5;
    const GAS_COST_MOD = 5;
    const GAS_COST_SMOD = 5;
    const GAS_COST_ADDMOD = 8;
    const GAS_COST_MULMOD = 8;
    const GAS_COST_EXP = 10;
    const GAS_COST_SIGNEXTEND = 5;

    // @notice 0x01 - ADD
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

        // Stack input:
        // 0 - a: first integer value to add.
        // 1 - b: second integer value to add.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the addition
        let (result) = SafeUint256.add(a, b);

        // Stack output:
        // a + b: integer result of the addition modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_ADD);
        return ctx;
    }

    // @notice 0x02 - MUL
    // @dev Multiplication operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_mul{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x02 - MUL") %}

        // Stack input:
        // 0 - a: first integer value to multiply.
        // 1 - b: second integer value to multiply.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the multiplication
        let (result) = SafeUint256.mul(a, b);

        // Stack output:
        // a * b: integer result of the multiplication modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_MUL);
        return ctx;
    }

    // @notice 0x03 - SUB
    // @dev Subtraction operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_sub{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x03 - SUB") %}

        // Stack input:
        // 0 - a: first integer value to sub.
        // 1 - b: second integer value to sub.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the subtraction
        let (result) = SafeUint256.sub_le(a, b);

        // Stack output:
        // a - b: integer result of the subtraction modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_SUB);
        return ctx;
    }

    // @notice 0x04 - DIV
    // @dev Division operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_div{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x04 - DIV") %}

        // Stack input:
        // 0 - a: numerator.
        // 1 - b: denominator.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the division
        let (result, _rem) = SafeUint256.div_rem(a, b);

        // Stack output:
        // a / b: integer result of the division modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_DIV);
        return ctx;
    }

    // @notice 0x05 - SDIV
    // @dev Signed division operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_sdiv{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x05 - SDIV") %}

        // Stack input:
        // 0 - a: numerator.
        // 1 - b: denominator.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the division
        let (result, _rem) = uint256_signed_div_rem(a, b);

        // Stack output:
        // a / b: signed integer result of the division modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_SDIV);
        return ctx;
    }

    // @notice 0x06 - MOD
    // @dev Modulo operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_mod{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x06 - MOD") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: modulo.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the modulo
        let (_result, rem) = SafeUint256.div_rem(a, b);

        // Stack output:
        // a % b:  integer result of the a % b
        let stack: model.Stack* = Stack.push(stack, rem);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_MOD);
        return ctx;
    }

    // @notice 0x07 - SMOD
    // @dev Signed modulo operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_smod{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x07 - SMOD") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: modulo.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the signed modulo
        let (_result, rem) = uint256_signed_div_rem(a, b);

        // Stack output:
        // a % b:  signed integer result of the a % b
        let stack: model.Stack* = Stack.push(stack, rem);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_SMOD);
        return ctx;
    }

    // @notice 0x08 - ADDMOD
    // @dev Addition modulo operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 8
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_addmod{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x08 - ADDMOD") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: number.
        // 1 - c: modulo.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);
        let (stack, c) = Stack.pop(stack);

        // Compute the addition
        let (result) = SafeUint256.add(a, b);
        // Compute the modulo
        let (_result, rem) = SafeUint256.div_rem(result, c);

        // Stack output:
        // integer result of a + b % c
        let stack: model.Stack* = Stack.push(stack, rem);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_ADDMOD);
        return ctx;
    }

    // @notice 0x09 - MULMOD
    // @dev Multiplication modulo operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 8
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_mulmod{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x09 - MULMOD") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: number.
        // 1 - c: modulos.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);
        let (stack, c) = Stack.pop(stack);

        // Compute the addition
        let (result) = SafeUint256.mul(a, b);
        // Compute the modulo
        let (_result, rem) = SafeUint256.div_rem(result, c);

        // Stack output:
        // integer result of the a * b % c
        let stack: model.Stack* = Stack.push(stack, rem);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_MULMOD);
        return ctx;
    }

    // @notice 0x0A - EXP
    // @dev Exp operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 10
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_exp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x0A - EXP") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: exponent.
        let stack = ctx.stack;
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // Compute the addition
        let result = internal_exp(a, b);

        // Stack output:
        // integer result of a ** b
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_EXP);
        return ctx;
    }

    // @notice 0x0B - SIGNEXTEND
    // @dev Exp operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 5
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return The pointer to the execution context.
    func exec_signextend{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x0B - SIGNEXTEND") %}

        // Stack input:
        // 0 - a: number.
        // 1 - b: exponent.
        let stack = ctx.stack;
        let (stack, b) = Stack.pop(stack);
        let (stack, x) = Stack.pop(stack);

        // Value is already a uint256
        let stack: model.Stack* = Stack.push(stack, x);
        let ctx = apply_context_changes(ctx, stack, GAS_COST_SIGNEXTEND);
        return ctx;
    }

    // @notice Internal exponentiation of two 256-bit integers from the stack.
    // @dev The result is modulo 2^256.
    // @param a The base.
    // @param b The exponent.
    // @return The result of the exponentiation.
    func internal_exp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        a: Uint256, b: Uint256
    ) -> Uint256 {
        let one_uint: Uint256 = Uint256(1, 0);
        let zero_uint: Uint256 = Uint256(0, 0);

        let (is_b_one) = uint256_eq(b, zero_uint);
        if (is_b_one == 1) {
            return one_uint;
        }
        let (is_b_ge_than_one) = uint256_le(zero_uint, b);
        if (is_b_ge_than_one == 1) {
            let (b_minus_one) = SafeUint256.sub_le(b, one_uint);
            let temp_pow = internal_exp(a, b_minus_one);
            let (res) = SafeUint256.mul(a, temp_pow);
            return res;
        }
        return zero_uint;
    }

    // @notice Apply changes to the execution context.
    // @param ctx The pointer to the execution context.
    // @param stack The pointer to the stack.
    // @param gas_cost The gas cost to increment.
    // @return The pointer to the execution context.
    func apply_context_changes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, stack: model.Stack*, gas_cost: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, gas_cost);
        return ctx;
    }
}
