// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.pow import pow
from starkware.cairo.common.bool import FALSE

from kakarot.memory import Memory
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from utils.utils import Helpers

// @title Sha3 opcodes.
// @notice This file contains the keccak opcode.
// @author @LucasLvy
// @custom:namespace Sha3
namespace Sha3 {
    const GAS_COST_SHA3 = 30;

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

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset for the beginning of the hash.
        // 1 - length: how many values we hash.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let length = popped[1];

        let (bigendian_data: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=length.low, element=bigendian_data, offset=offset.low
        );

        let (local dest: felt*) = alloc();
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=length.low,
            bytes=bigendian_data,
            index=0,
            size=length.low,
            bytes8=0,
            bytes8_shift=0,
            dest=dest,
            dest_index=0,
        );

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(inputs=dest, n_bytes=length.low);

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }
        let stack: model.Stack* = Stack.push(self=stack, element=result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Increment gas used.
        let (minimum_word_size) = Helpers.minimum_word_count(length.low);
        let dynamic_gas = 6 * minimum_word_size + gas_cost;

        let ctx = ExecutionContext.increment_gas_used(
            self=ctx, inc_value=GAS_COST_SHA3 + dynamic_gas
        );

        return ctx;
    }
}
