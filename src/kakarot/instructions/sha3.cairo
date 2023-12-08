// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256

from kakarot.evm import EVM
from kakarot.gas import Gas
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.bytes import bytes_to_bytes8_little_endian

// @title Sha3 opcodes.
// @notice This file contains the keccak opcode.
namespace Sha3 {
    // @notice SHA3.
    // @dev Hashes n memory elements at m memory offset.
    // @custom:since Frontier
    // @custom:group Sha3
    // @custom:gas 30
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 1
    // @param evm The pointer to the execution context
    // @return EVM The pointer to the updated execution context.
    func exec_sha3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let length = popped[1];

        let memory_expansion_cost = Gas.memory_expansion_cost(
            evm.memory.words_len, offset.low + length.low
        );
        let evm = EVM.charge_gas(evm, memory_expansion_cost);
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (bigendian_data: felt*) = alloc();
        let memory = Memory.load_n(evm.memory, length.low, bigendian_data, offset.low);

        let (local dst: felt*) = alloc();
        bytes_to_bytes8_little_endian(dst, length.low, bigendian_data);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(dst, length.low);
        }
        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

        Stack.push_uint256(result);

        let evm = EVM.update_memory(evm, memory);

        return evm;
    }
}
