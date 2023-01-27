// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from kakarot.precompiles.sha256 import PrecompileSHA256
from utils.utils import Helpers

@external
func test__sha256{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(data_len: felt, data: felt*) -> (hash_len: felt, hash: felt*) {
    alloc_locals;
    let (hash_len, hash, gas_used) = PrecompileSHA256.run(
        PrecompileSHA256.PRECOMPILE_ADDRESS, data_len, data
    );
    let (minimum_word_size) = Helpers.minimum_word_count(data_len);
    assert gas_used = 3 * minimum_word_size + PrecompileSHA256.GAS_COST_SHA256;

    return (hash_len, hash);
}
