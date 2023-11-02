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
from starkware.cairo.lang.compiler.lib.registers import get_fp_and_pc

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.errors import Errors

// @title Stop and Arithmetic operations opcodes.
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

    func exec_arithmetic_operation{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        local opcode: model.Opcode*;

        // See evm.cairo, pc is increased before entering the opcode
        let opcode_number = [ctx.call_context.bytecode + ctx.program_counter - 1];

        // To cast the codeoffset opcodes_label to a model.Opcode*, we need to use it to offset
        // the current pc. We get the pc from the `get_fp_and_pc` util and assign a codeoffset (pc_label) to it.
        // In short, this boilds down to: opcode = pc + offset - pc = offset
        let (_, pc) = get_fp_and_pc();

        pc_label:
        assert opcode = cast(
            pc + (opcodes_label - pc_label) + opcode_number * model.Opcode.SIZE, model.Opcode*
        );

        let stack_underflow = is_le(ctx.stack.size, opcode.stack_input - 1);
        if (stack_underflow != 0) {
            let (revert_reason_len, revert_reason) = Errors.stackUnderflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }
        let out_of_gas = is_le(ctx.call_context.gas_limit, ctx.gas_used + opcode.gas - 1);
        if (out_of_gas != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfGas();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let (local stack, popped) = Stack.pop_n(ctx.stack, opcode.stack_input);

        // offset is 1 (new line) + 4 (call + op + jmp + end) per opcode
        // opcode is offset from by 0x1 (index of the first opcode)
        tempvar offset = 1 + 4 * (opcode_number - 0x1);

        // Prepare arguments
        [ap] = range_check_ptr, ap++;
        [ap] = popped, ap++;

        // call opcode
        jmp rel offset;
        call Internals.add;  // 0x1
        jmp end;
        call Internals.mul;  // 0x2
        jmp end;
        call Internals.sub;  // 0x3
        jmp end;
        call Internals.div;  // 0x4
        jmp end;
        call Internals.sdiv;  // 0x5
        jmp end;
        call Internals.mod;  // 0x6
        jmp end;
        call Internals.smod;  // 0x7
        jmp end;
        call Internals.addmod;  // 0x8
        jmp end;
        call Internals.mulmod;  // 0x9
        jmp end;
        call Internals.exp;  // 0xa
        jmp end;
        call Internals.signextend;  // 0xb
        jmp end;

        end:
        // Parse results from call
        // All the implementation share the same return signature, which is range_check_ptr in implicit args
        // and a Uint256 for the value
        let range_check_ptr = [ap - 3];
        let result = Uint256([ap - 2], [ap - 1]);

        // Rebind args with fp
        // Function args are in [fp - n - 2: fp - 2]
        // locals are retrieved from [fp] in the order they are defined
        let syscall_ptr = cast([fp - 7], felt*);
        let pedersen_ptr = cast([fp - 6], HashBuiltin*);
        let bitwise_ptr = cast([fp - 4], BitwiseBuiltin*);
        let ctx = cast([fp - 3], model.ExecutionContext*);
        let opcode = cast([fp], model.Opcode*);
        let stack = cast([fp + 1], model.Stack*);

        // Finalize opcode
        let stack = Stack.push_uint256(stack, result);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.increment_gas_used(ctx, opcode.gas);
        return ctx;
    }
}

namespace Internals {
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

        return uint256_exp(a, b);
    }

    func signextend{range_check_ptr}(popped: Uint256*) -> Uint256 {
        let b = popped[0];
        let a = popped + Uint256.SIZE;

        return [a];
    }

    // @notice Internal exponentiation of two 256-bit integers.
    // @dev The result is modulo 2^256.
    // @param a The base.
    // @param b The exponent.
    // @return The result of the exponentiation.
    func uint256_exp{range_check_ptr}(a: Uint256, b: Uint256) -> Uint256 {
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
        let pow = uint256_exp(a, b_minus_one);
        let (res, _) = uint256_mul(a, pow);
        return res;
    }
}

// See model.Opcode
// gas
// stack_input
opcodes_label:
// STOP;
dw 0;
dw 0;
// ADD;
dw 3;
dw 2;
// MUL;
dw 5;
dw 2;
// SUB;
dw 3;
dw 2;
// DIV;
dw 5;
dw 2;
// SDIV;
dw 5;
dw 2;
// MOD;
dw 5;
dw 2;
// SMOD;
dw 5;
dw 2;
// ADDMOD;
dw 8;
dw 3;
// MULMOD;
dw 8;
dw 3;
// EXP;
dw 10;
dw 2;
// SIGNEXTEND;
dw 5;
dw 2;
