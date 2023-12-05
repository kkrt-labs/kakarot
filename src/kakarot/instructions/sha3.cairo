// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.pow import pow
from starkware.cairo.common.bool import FALSE, TRUE

from kakarot.memory import Memory
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.errors import Errors
from utils.utils import Helpers
from utils.bytes import bytes_to_bytes8_little_endian

// @title Sha3 opcodes.
// @notice This file contains the keccak opcode.
// @author @LucasLvy
// @custom:namespace Sha3
namespace Sha3 {
    // @notice SHA3.
    // @dev Hashes n memory elements at m memory offset.
    // @custom:since Frontier
    // @custom:group Sha3
    // @custom:gas 30
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_sha3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 2);
        let offset = popped[0];
        let length = popped[1];

        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + length.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            let ctx = ExecutionContext.update_stack(ctx, stack);
            return ctx;
        }

        let (bigendian_data: felt*) = alloc();
        let memory = Memory.load_n(ctx.memory, length.low, bigendian_data, offset.low);

        let (local dest: felt*) = alloc();
        bytes_to_bytes8_little_endian(dest, length.low, bigendian_data);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(inputs=dest, n_bytes=length.low);
        }
        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

        tempvar hash = new Uint256(result.low, result.high);
        let stack = Stack.push(stack, hash);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        return ctx;
    }
}
