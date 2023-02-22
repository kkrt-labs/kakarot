// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_signed_div_rem,
    uint256_le,
    uint256_mul,
    uint256_eq,
    uint256_sub,
    uint256_unsigned_div_rem,
    uint256_mul_div_mod,
)
from starkware.cairo.common.bool import FALSE, TRUE

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Arithmetic operations opcodes.
// @notice This contract contains the functions to execute for arithmetic operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace StopAndArithmeticOperations
namespace StopAndArithmeticOperations {
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

    // @notice 0x00 - STOP
    // @dev Halts execution
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 0
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext Updated execution context.
    func exec_stop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = ExecutionContext.stop(ctx_ptr);
        return ctx;
    }

    // @notice 0x01 - ADD
    // @dev Addition operation
    // @custom:since Frontier
    // @custom:group Stop and Arithmetic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_add{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: first integer value to add.
        // 1 - b: second integer value to add.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the addition
        let (result, _) = uint256_add(a, b);

        // Stack output:
        // a + b: integer result of the addition modulo 2^256
        let stack: model.Stack* = Stack.push(self=stack, element=result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_ADD);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_mul{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: first integer value to multiply.
        // 1 - b: second integer value to multiply.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the multiplication
        let (result, _) = uint256_mul(a, b);

        // Stack output:
        // a * b: integer result of the multiplication modulo 2^256
        let stack: model.Stack* = Stack.push(stack, result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_MUL);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_sub{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: first integer value to sub.
        // 1 - b: second integer value to sub.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the subtraction
        let (result) = uint256_sub(a, b);

        // Stack output:
        // a - b: integer result of the subtraction modulo 2^256
        let stack: model.Stack* = Stack.push(self=stack, element=result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_SUB);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_div{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: numerator.
        // 1 - b: denominator.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the division
        let (result, _) = uint256_unsigned_div_rem(a, b);

        // Stack output:
        // a / b: integer result of the division modulo 2^256
        let stack: model.Stack* = Stack.push(self=stack, element=result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_DIV);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_sdiv{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: numerator.
        // 1 - b: denominator.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the division
        let (result, _) = uint256_signed_div_rem(a, b);

        // Stack output:
        // a / b: signed integer result of the division modulo 2^256
        let stack: model.Stack* = Stack.push(self=stack, element=result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_SDIV);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_mod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: modulo.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the modulo
        let (_, rem) = uint256_unsigned_div_rem(a, b);

        // Stack output:
        // a % b:  integer result of the a % b
        let stack: model.Stack* = Stack.push(self=stack, element=rem);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_MOD);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_smod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: modulo.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the signed modulo
        let (_, rem) = uint256_signed_div_rem(a, b);

        // Stack output:
        // a % b:  signed integer result of the a % b
        let stack: model.Stack* = Stack.push(self=stack, element=rem);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_SMOD);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_addmod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: number.
        // 1 - c: modulo.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        let a = popped[0];
        let b = popped[1];
        let c = popped[2];

        // Compute the addition
        let (result, _) = uint256_add(a, b);
        // Compute the modulo
        let (_, rem) = uint256_unsigned_div_rem(result, c);

        // Stack output:
        // integer result of a + b % c
        let stack: model.Stack* = Stack.push(self=stack, element=rem);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_ADDMOD);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_mulmod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: number.
        // 1 - c: modulos.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        let a = popped[0];
        let b = popped[1];
        let c = popped[2];

        // Compute the mul mod
        let (_, _, rem) = uint256_mul_div_mod(a, b, c);

        // Stack output:
        // integer result of the a * b % c
        let stack: model.Stack* = Stack.push(self=stack, element=rem);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_MULMOD);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_exp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: exponent.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the addition
        let result = internal_exp(a, b);

        // Stack output:
        // integer result of a ** b
        let stack: model.Stack* = Stack.push(self=stack, element=result);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_EXP);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_signextend{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Stack input:
        // 0 - a: number.
        // 1 - b: exponent.
        let stack = ctx.stack;
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let b = popped[0];
        let a = popped[1];

        // Value is already a uint256
        let stack: model.Stack* = Stack.push(self=stack, element=a);
        let ctx = apply_context_changes(ctx=ctx, stack=stack, gas_cost=GAS_COST_SIGNEXTEND);
        return ctx;
    }

    // @notice Internal exponentiation of two 256-bit integers from the stack.
    // @dev The result is modulo 2^256.
    // @param a The base.
    // @param b The exponent.
    // @return The result of the exponentiation.
    func internal_exp{range_check_ptr}(a: Uint256, b: Uint256) -> Uint256 {
        let one_uint: Uint256 = Uint256(1, 0);
        let zero_uint: Uint256 = Uint256(0, 0);

        let (is_b_one) = uint256_eq(b, zero_uint);
        if (is_b_one != FALSE) {
            return one_uint;
        }
        let (is_b_ge_than_one) = uint256_le(zero_uint, b);
        if (is_b_ge_than_one == FALSE) {
            return zero_uint;
        }
        let (b_minus_one) = uint256_sub(b, one_uint);
        let temp_pow = internal_exp(a=a, b=b_minus_one);
        let (res, _) = uint256_mul(a, temp_pow);
        return res;
    }

    // @notice Apply changes to the execution context.
    // @param ctx The pointer to the execution context.
    // @param stack The pointer to the stack.
    // @param gas_cost The gas cost to increment.
    // @return ExecutionContext The pointer to the execution context.
    func apply_context_changes(
        ctx: model.ExecutionContext*, stack: model.Stack*, gas_cost: felt
    ) -> model.ExecutionContext* {
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=gas_cost);
        return ctx;
    }
}
