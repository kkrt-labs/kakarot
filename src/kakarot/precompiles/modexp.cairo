// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers

// @title ModExp Precompile related functions.
// @notice This file contains the logic required to run the modexp precompile
// @author @dragan2234
// @custom:namespace PrecompileModExp
namespace PrecompileModExp {
    const PRECOMPILE_ADDRESS = 0x05;
    const GAS_COST_MOD_EXP = 200;
    const MOD_EXP_BYTES_LEN = 32;


    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return The output length, output array, and gas usage of precompile.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt
    ) {
        alloc_locals;
        let BSize: Uint256 = Helpers.bytes32_to_uint256(input);
        let ESize: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN);
        let MSize: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN * 2);
        let B: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3, BSize.low);
        let E: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3 + BSize.low, ESize.low);
        let M: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3 + BSize.low + ESize.low, MSize.low);
        // assert BSize.low = 1;
        // assert ESize.low = 32;
        // assert MSize.low = 1;
        // assert B = Uint256(low=8,high=0);
        // assert E = Uint256(low=340282366920938463463374607431768211455,high=340282366920938463463374607431768211455);
        // assert M = Uint256(low=11,high=0);
        with_attr error_message("Kakarot: modexp failed") {
            let (result) = Helpers.uint256_expmod(B,E,M);
        }
        // assert result = Uint256(low=10,high=0);
        let (bytes_result_len, output: felt*) = Helpers.uint256_to_bytes_array(result);

        return (bytes_result_len, output, 0);
    }
}
