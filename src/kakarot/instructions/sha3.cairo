// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_not_zero

from kakarot.evm import EVM
from kakarot.gas import Gas
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.bytes import bytes_to_bytes8_little_endian

namespace Sha3 {
    func exec_sha3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        stack: model.Stack*,
        memory: model.Memory*,
        state: model.State*,
    }(evm: model.EVM*) -> model.EVM* {
        alloc_locals;

        let (popped) = Stack.pop_n(2);
        let offset = popped[0];
        let size = popped[1];

        let memory_expansion = Gas.memory_expansion_cost_saturated(memory.words_len, offset, size);
        let (words, _) = unsigned_div_rem(size.low + 31, 32);
        let words_gas_cost_low = Gas.KECCAK256_WORD * words;
        tempvar words_gas_cost_high = is_not_zero(size.high) * 2 ** 128;
        let evm = EVM.charge_gas(
            evm, memory_expansion.cost + words_gas_cost_low + words_gas_cost_high
        );
        if (evm.reverted != FALSE) {
            return evm;
        }

        let (bigendian_data: felt*) = alloc();
        Memory.load_n(size.low, bigendian_data, offset.low);

        let (local dst: felt*) = alloc();
        bytes_to_bytes8_little_endian(dst, size.low, bigendian_data);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(dst, size.low);
        }
        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

        Stack.push_uint256(result);

        return evm;
    }
}
