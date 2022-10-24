// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak_bigend, finalize_keccak
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.constants import Constants
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address

from kakarot.model import model

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
    // @return The pointer to the updated execution context.
    func exec_sha3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ 
        import logging
        logging.info("0x20 - SHA3")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset for the begining of the hash.
        // 1 - length: how many values we hash.
        let (stack, local offset: Uint256) = Stack.pop(stack);
        let (stack, local length: Uint256) = Stack.pop(stack);

        assert_le(offset.low + length.low, Constants.MAX_MEMORY_OFFSET);
        let (self) = get_contract_address();

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            let (result) = keccak_bigend(
                inputs=ctx.memory.elements + offset.low, n_bytes=length.low
            );

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SHA3);
        return ctx;
    }
}
