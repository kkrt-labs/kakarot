// SPDX-License-Identifier: MIT
// original code from: https://github.com/cartridge-gg/cairo-sha256

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Internal dependencies
from kakarot.interfaces.interfaces import ICairo1Helpers
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from utils.utils import Helpers

// @title SHA2-256 Precompile related functions.
// @notice This file contains the logic required to run the SHA2-256 precompile
// @author @ftupas
// @custom:namespace PrecompileSHA256
namespace PrecompileSHA256 {
    const PRECOMPILE_ADDRESS = 0x02;
    const GAS_COST_SHA256 = 60;

    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return output_len The output length.
    // @return output The output array.
    // @return gas_used The gas usage of precompile.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Prepare input bytes array to words of 32 bits (big endian).
        let (prepared_input: felt*) = alloc();
        let (
            prepared_input_len,
            prepared_input: felt*,
            last_input_word: felt,
            last_word_num_bytes: felt,
        ) = Helpers.bytes_to_bytes4_array(input_len, input, 0, prepared_input);

        let (helpers_class) = Kakarot_cairo1_helpers_class_hash.read();
        let (_, hash_u32_array) = ICairo1Helpers.library_call_compute_sha256_u32_array(
            class_hash=helpers_class,
            input_len=prepared_input_len,
            input=prepared_input,
            last_input_word=last_input_word,
            last_input_num_bytes=last_word_num_bytes,
        );

        // Split words and return bytes hash code.
        let (hash_bytes_array: felt*) = alloc();
        let (_, hash_bytes_array: felt*) = Helpers.bytes4_array_to_bytes(
            8, hash_u32_array, 0, hash_bytes_array
        );
        let (minimum_word_size) = Helpers.minimum_word_count(input_len);
        return (32, hash_bytes_array, 12 * minimum_word_size + GAS_COST_SHA256, 0);
    }
}
