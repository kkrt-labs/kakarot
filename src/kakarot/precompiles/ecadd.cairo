// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_add
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers

// @title EcAdd Precompile related functions.
// @notice This file contains the logic required to run the ec_add precompile
// using Starkware's cairo_secp library
// @author @pedrobergamini
// @custom:namespace PrecompileEcAdd
namespace PrecompileEcAdd {
    const PRECOMPILE_ADDRESS = 0x06;
    const GAS_COST_EC_ADD = 150;
    const ECPOINT_BYTES_LEN = 32;

    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return The output length, output array, and gas usage of precompile.
    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        input_len: felt, input: felt*
    ) -> (output_len: felt, output: felt*, gas_used: felt) {
        alloc_locals;

        let input_word0 = Helpers.load_word(ECPOINT_BYTES_LEN, input);
        let input_word1 = Helpers.load_word(ECPOINT_BYTES_LEN, input + ECPOINT_BYTES_LEN);
        let input_word2 = Helpers.load_word(ECPOINT_BYTES_LEN, input + ECPOINT_BYTES_LEN * 2);
        let input_word3 = Helpers.load_word(ECPOINT_BYTES_LEN, input + ECPOINT_BYTES_LEN * 3);

        let x0: BigInt3 = Helpers.to_bigint(input_word0);
        let y0: BigInt3 = Helpers.to_bigint(input_word1);
        let x1: BigInt3 = Helpers.to_bigint(input_word2);
        let y1: BigInt3 = Helpers.to_bigint(input_word3);

        with_attr error_message("Kakarot: ec_add failed") {
            let point0: EcPoint = EcPoint(x0, y0);
            let point1: EcPoint = EcPoint(x1, y1);
            let result: EcPoint = ec_add(point0, point1);
        }

        let (output: felt*) = alloc();
        let output_x = Helpers.bigint_to_felt(result.x);
        let output_y = Helpers.bigint_to_felt(result.y);
        Helpers.split_word(output_x, ECPOINT_BYTES_LEN, output);
        Helpers.split_word(output_y, ECPOINT_BYTES_LEN, output + ECPOINT_BYTES_LEN);

        return (ECPOINT_BYTES_LEN * 2, output, GAS_COST_EC_ADD);
    }
}
