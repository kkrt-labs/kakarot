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
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.errors import Errors

// @title Arithmetic operations opcodes.
// @notice This contract contains the functions to execute for arithmetic operations opcodes.
namespace StopAndArithmeticOperations {
    func exec_stop{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // return_data stored the return_data for the last executed sub context
        // see CALLs opcodes. When we run the STOP opcode, we stop the current
        // execution context with *no* return data (unlike RETURN and REVERT).
        // hence we just clear the return_data and stop.
        let (return_data: felt*) = alloc();
        let ctx = ExecutionContext.stop(ctx, 0, return_data, FALSE);
        return ctx;
    }

    func exec_add{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x01);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_mul{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x02);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_sub{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x03);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_div{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x04);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_sdiv{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x05);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_mod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x06);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_smod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x07);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_addmod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x08);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_mulmod{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x09);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_exp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x0a);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }

    func exec_signextend{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        let opcode = Internals.get_opcode(0x0b);
        return Internals.exec_arithmetic_operation(ctx, opcode);
    }
}

namespace Internals {
    func get_opcode(index: felt) -> model.Opcode* {
        let (opcode: model.Opcode*) = get_label_location(opcodes);
        return opcode + index * model.Opcode.SIZE;

        // See model.Opcode
        // number
        // gas
        // stack_input
        // stack_diff
        // static_disabled
        opcodes:
        // STOP;
        dw 0x00;
        dw 0;
        dw 0;
        dw 0;
        dw 0;
        // ADD;
        dw 0x01;
        dw 3;
        dw 2;
        dw -1;
        dw 0;
        // MUL;
        dw 0x02;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
        // SUB;
        dw 0x03;
        dw 3;
        dw 2;
        dw -1;
        dw 0;
        // DIV;
        dw 0x04;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
        // SDIV;
        dw 0x05;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
        // MOD;
        dw 0x06;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
        // SMOD;
        dw 0x07;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
        // ADDMOD;
        dw 0x08;
        dw 8;
        dw 3;
        dw -2;
        dw 0;
        // MULMOD;
        dw 0x09;
        dw 8;
        dw 3;
        dw -2;
        dw 0;
        // EXP;
        dw 0x0A;
        dw 10;
        dw 2;
        dw -1;
        dw 0;
        // SIGNEXTEND;
        dw 0x0B;
        dw 5;
        dw 2;
        dw -1;
        dw 0;
    }

    func exec_arithmetic_operation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, opcode: model.Opcode*) -> model.ExecutionContext* {
        alloc_locals;
        local stack: model.Stack*;

        let stack_underflow = is_le(ctx.stack.size, opcode.stack_input - 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (_stack, popped) = Stack.pop_n(ctx.stack, opcode.stack_input);

        assert stack = _stack;
        tempvar offset = 1 + 4 * (opcode.number - 0x1);

        // Prepare arguments
        [ap] = range_check_ptr, ap++;
        [ap] = popped, ap++;

        // call opcode
        jmp rel offset;
        call add;  // 0x1
        jmp end;
        call mul;  // 0x2
        jmp end;
        call sub;  // 0x3
        jmp end;
        call div;  // 0x4
        jmp end;
        call sdiv;  // 0x5
        jmp end;
        call mod;  // 0x6
        jmp end;
        call smod;  // 0x7
        jmp end;
        call addmod;  // 0x8
        jmp end;
        call mulmod;  // 0x9
        jmp end;
        call exp;  // 0xa
        jmp end;
        call signextend;  // 0xb
        jmp end;

        end:
        // Parse results from call
        let range_check_ptr = [ap - 3];
        tempvar result = new Uint256([ap - 2], [ap - 1]);

        // Retrieve stack from locals
        let stack = cast([fp], model.Stack*);

        // Rebind function args with fp
        let syscall_ptr = cast([fp - 8], felt*);
        let pedersen_ptr = cast([fp - 7], HashBuiltin*);
        let bitwise_ptr = cast([fp - 5], BitwiseBuiltin*);
        let ctx = cast([fp - 4], model.ExecutionContext*);
        let opcode = cast([fp - 3], model.Opcode*);

        // Finalize opcode
        let stack = Stack.push(stack, result);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=opcode.gas);
        return ctx;
    }

    func add{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (result, _) = uint256_add(a, b);
        return result;
    }

    func mul{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (result, _) = uint256_mul(a, b);
        return result;
    }

    func sub{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (result) = uint256_sub(a, b);
        return result;
    }

    func div{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (result, _) = uint256_unsigned_div_rem(a, b);
        return result;
    }

    func sdiv{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (result, _) = uint256_signed_div_rem(a, b);
        return result;
    }

    func mod{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (_, result) = uint256_unsigned_div_rem(a, b);
        return result;
    }

    func smod{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        let (_, result) = uint256_signed_div_rem(a, b);
        return result;
    }

    func addmod{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];
        let c = popped[2];

        let (sum, _) = uint256_add(a, b);
        let (_, result) = uint256_unsigned_div_rem(sum, c);

        return result;
    }

    func mulmod{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];
        let c = popped[2];

        let (_, _, result) = uint256_mul_div_mod(a, b, c);
        return result;
    }

    func exp{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let a = popped[0];
        let b = popped[1];

        return internal_exp(a, b);
    }

    func signextend{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let b = popped[0];
        let a = popped + Uint256.SIZE;

        return [a];
    }

    // @notice Internal exponentiation of two 256-bit integers from the stack.
    // @dev The result is modulo 2^256.
    // @param a The base.
    // @param b The exponent.
    // @return The result of the exponentiation.
    func internal_exp{range_check_ptr}(a: Uint256, b: Uint256) -> Uint256 {
        let one_uint = Uint256(1, 0);
        let zero_uint = Uint256(0, 0);

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
}
