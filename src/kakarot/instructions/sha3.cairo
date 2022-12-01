// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.pow import pow
from starkware.cairo.common.bool import FALSE

from kakarot.memory import Memory
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

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
    // @return The pointer to the updated execution context.
    func exec_sha3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset for the begining of the hash.
        // 1 - length: how many values we hash.
        let (stack, popped) = Stack.pop_n(self=stack, n=2);
        let offset = popped[0];
        let length = popped[1];

        let (memory, cost) = Memory.ensure_length(self=ctx.memory, length=offset.low + length.low);

        // Update context memory.
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);

        let (bigendian_data: felt*) = alloc();
        let memory = Memory.load_n(
            self=memory, element_len=length.low, element=bigendian_data, offset=offset.low
        );
        let (local dest: felt*) = alloc();
        bytes_to_byte8_little_endian(
            bytes_len=length.low,
            bytes=bigendian_data,
            index=0,
            size=length.low,
            byte8=0,
            byte8_shift=0,
            dest=dest,
            dest_index=0,
        );

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = keccak_bigend(inputs=dest, n_bytes=length.low);

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }
        let stack: model.Stack* = Stack.push(self=stack, element=result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        // Increment gas used.
        let minimum_word_size = (length.low + 31) / 32;
        let dynamic_gas = 6 * minimum_word_size + cost;

        let ctx = ExecutionContext.increment_gas_used(
            self=ctx, inc_value=GAS_COST_SHA3 + dynamic_gas
        );

        return ctx;
    }

    // TODO: natspec
    func bytes_to_byte8_little_endian{range_check_ptr}(
        bytes_len: felt,
        bytes: felt*,
        index: felt,
        size: felt,
        byte8: felt,
        byte8_shift: felt,
        dest: felt*,
        dest_index: felt,
    ) {
        alloc_locals;
        if (index == size) {
            return ();
        }

        local current_byte;
        let out_of_bound = is_le(a=bytes_len, b=index);
        if (out_of_bound != FALSE) {
            current_byte = 0;
        } else {
            assert current_byte = [bytes + index];
        }

        let (bit_shift) = pow(256, byte8_shift);

        let _byte8 = byte8 + bit_shift * current_byte;

        let byte8_full = is_le(a=7, b=byte8_shift);
        let end_of_loop = is_le(size, index + 1);
        let write_to_dest = is_le(1, byte8_full + end_of_loop);
        if (write_to_dest != FALSE) {
            assert dest[dest_index] = _byte8;
            return bytes_to_byte8_little_endian(
                bytes_len, bytes, index + 1, size, 0, 0, dest, dest_index + 1
            );
        }
        return bytes_to_byte8_little_endian(
            bytes_len, bytes, index + 1, size, _byte8, byte8_shift + 1, dest, dest_index
        );
    }
}
