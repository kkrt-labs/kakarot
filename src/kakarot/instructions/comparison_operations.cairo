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
    uint256_not,
    uint256_xor,
    uint256_mul,
    uint256_sub,
)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import TRUE, FALSE

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.errors import Errors

const BIT_MASK = 2 ** 127;

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
    const GAS_COST_XOR = 3;
    const GAS_COST_BYTE = 3;
    const GAS_COST_EQ = 3;
    const GAS_COST_SHL = 3;
    const GAS_COST_SHR = 3;
    const GAS_COST_SAR = 3;
    const GAS_COST_NOT = 3;

    // @notice 0x10 - LT
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_lt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the comparison
        let (result) = uint256_lt(a, b);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_LT);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_gt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the comparison
        let (result) = uint256_lt(b, a);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_GT);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_slt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side signed integer.
        // 1 - b: right side signed integer.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // Compute the comparison
        let (result) = uint256_signed_lt(a, b);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SLT);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_sgt{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let b = popped[0];
        let a = popped[1];

        // Compute the comparison
        let (result) = uint256_signed_lt(a, b);

        // Stack output:
        // a < b: integer result of comparison a less than b
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SGT);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_eq{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: left side integer.
        // 1 - b: right side integer.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let b = popped[0];
        let a = popped[1];

        // Compute the comparison
        let (result) = uint256_eq(a, b);

        // Stack output:
        // a == b: 1 if the left side is equal to the right side, 0 otherwise.
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_EQ);
        return ctx;
    }

    // @notice 0x15 - ISZERO
    // @dev Comparison operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_iszero{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: integer
        let (stack, a) = Stack.pop(stack);

        // a == 0: 1 if a is 0, 0 otherwise.
        let (result) = uint256_eq(a=[a], b=Uint256(0, 0));

        // Stack output:
        // a == 0: 1 if a is 0, 0 otherwise.
        let stack: model.Stack* = Stack.push_uint128(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_ISZERO);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_and{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input
        // a: first binary value.
        // b: second binary value.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // a & b: the bitwise AND result.
        let (result) = uint256_and(a, b);

        // Stack output:
        // a & b: the bitwise AND result.
        let stack = Stack.push_uint256(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_AND);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_or{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input
        // a: first binary value.
        // b: second binary value.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let a = popped[0];
        let b = popped[1];

        // a & b: the bitwise AND result.
        let (result) = uint256_or(a, b);

        // Stack output:
        // a & b: the bitwise AND result.
        let stack = Stack.push_uint256(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_OR);
        return ctx;
    }

    // @notice 0x18 - XOR
    // @dev Comparison operation
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_xor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input
        // a: first binary value.
        // b: second binary value.
        let (stack, a) = Stack.pop(stack);
        let (stack, b) = Stack.pop(stack);

        // a & b: the bitwise XOR result.
        let (result) = uint256_xor([a], [b]);

        // Stack output:
        // a & b: the bitwise XOR result.
        let stack = Stack.push_uint256(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_XOR);
        return ctx;
    }

    // @notice 0x1A - BYTE
    // @dev Bitwise operation
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_byte{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - i: offset.
        // 1 - x: value.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let value = popped[1];

        // compute y = (x >> (248 - i * 8)) & 0xFF
        let (mul, _) = uint256_mul(offset, Uint256(8, 0));
        let (right) = uint256_sub(Uint256(248, 0), mul);
        let (shift_right) = uint256_shr(value, right);
        let (result) = uint256_and(shift_right, Uint256(0xFF, 0));

        // Stack output:
        // The result of the shift operation.
        let stack = Stack.push_uint256(stack, result);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_BYTE);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_shl{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - shift: integer
        // 1 - value: integer
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let shift = popped[0];
        let value = popped[1];

        // Left shift `value` by `shift`.
        let (result) = uint256_shl(a=value, b=shift);

        // Stack output:
        // The result of the shift operation.
        let stack = Stack.push_uint256(stack, result);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SHL);
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
    // @return ExecutionContext The pointer to the execution context.
    func exec_shr{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - shift: integer
        // 1 - value: integer
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let shift = popped[0];
        let value = popped[1];

        // Right shift `value` by `shift`.
        let (result) = uint256_shr(a=value, b=shift);

        // Stack output:
        // The result of the shift operation.
        let stack = Stack.push_uint256(stack, result);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SHR);
        return ctx;
    }

    // @notice 0x1D - SAR
    // @dev Bitwise operation
    // @custom:since Constantinople
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_sar{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack_underflow = is_le(ctx.stack.size, 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - shift: integer
        // 1 - value: integer
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let shift = popped[0];
        let value = popped[1];

        // In C, SAR would be something like that (on a 4 bytes int):
        // ```
        // int sign = -((unsigned) x >> 31);
        // int sar = (sign^x) >> n ^ sign;
        // ```
        // This is the cairo adaptation

        // (unsigned) x >> 31 : extract the left-most bit (i.e. the sign).
        let (_sign) = uint256_shr(value, Uint256(255, 0));

        // Declare low and high as tempvar because we can't declare a Uint256 as tempvar.
        tempvar low;
        tempvar high;
        if (_sign.low == 0) {
            // If sign is positive, set it to 0.
            low = 0;
            high = 0;
        } else {
            // If sign is negative, set the number to -1.
            low = 0xffffffffffffffffffffffffffffffff;
            high = 0xffffffffffffffffffffffffffffffff;
        }

        // Rebuild the `sign` variable from `low` and `high`.
        let sign = Uint256(low, high);

        // `sign ^ x`
        let (step1) = uint256_xor(sign, value);
        // `sign ^ x >> n`
        let (step2) = uint256_shr(step1, shift);
        // `sign & x >> n ^ sign`
        let (result) = uint256_xor(step2, sign);

        // Stack output:
        // The result of the shift operation.
        let stack = Stack.push_uint256(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SAR);
        return ctx;
    }

    // @notice 0x19 - Not
    // @dev Bitwise operation
    // @custom:since Frontier
    // @custom:group Comparison & Bitwise Logic Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return ExecutionContext The pointer to the execution context.
    func exec_not{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let stack = ctx.stack;

        // Stack input:
        // 0 - a: binary value
        let (stack, a) = Stack.pop(stack);

        // Bitwise NOT operation
        let (result) = uint256_not([a]);

        // Stack output:
        // The result of the shift operation.
        let stack = Stack.push_uint256(stack, result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_NOT);
        return ctx;
    }
}
