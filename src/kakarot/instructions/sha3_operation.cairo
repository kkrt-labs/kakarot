// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s, finalize_keccak
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.constants import Constants
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address

from kakarot.model import model

@contract_interface
namespace ISha3 {
    func sha3_inner(elements_len: felt, elements: Uint256*) -> (res: Uint256) {
    }
}
namespace Sha3Operation {
    const GAS_COST_SHA3 = 30;

    func exec_sha3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x20 - SHA3") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset for the begining of the hash.
        // 1 - length: how many values we hash.
        let (stack, offset) = Stack.pop(stack);
        let (stack, length) = Stack.pop(stack);

        assert_le(offset.low + length.low, Constants.MAX_MEMORY_OFFSET);
        let (bitwise_ptr: BitwiseBuiltin*) = alloc();
        // %{ print(ids.offset.low, ids.length.low, memory[ids.ctx.memory.elements.address_]) %}
        tempvar elt_ptr: Uint256* = ctx.memory.elements;
        tempvar val: Uint256 = elt_ptr[0];
        %{ print(ids.offset.low, str(ids.val.low), ids.val.high) %}
        let (self) = get_contract_address();

        let (result) = ISha3.sha3_inner(
            contract_address=self, elements_len=length.low, elements=elt_ptr + offset.low
        );
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=result);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_SHA3);
        return ctx;
    }

    func sha3_inner{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
        elements_len: felt, elements: Uint256*
    ) -> Uint256 {
        alloc_locals;
        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            %{ print(ids.n_elements, memory[ids.elements.address_]) %}
            let (result) = keccak_uint256s{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
            }(n_elements=elements_len, elements=elements);
            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }
        return result;
    }
}
