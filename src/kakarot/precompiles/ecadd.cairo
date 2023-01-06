// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
<<<<<<< HEAD
=======
from starkware.cairo.common.alloc import alloc
>>>>>>> main
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.alt_bn128.alt_bn128_g1 import G1Point, ALT_BN128
from utils.utils import Helpers

// @title EcAdd Precompile related functions.
// @notice This file contains the logic required to run the ec_add precompile
// using Starkware's cairo_secp library
// @author @pedrobergamini
// @custom:namespace PrecompileEcAdd
namespace PrecompileEcAdd {
    const PRECOMPILE_ADDRESS = 0x06;
    const GAS_COST_EC_ADD = 150;
    const G1POINT_BYTES_LEN = 32;

    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return The output length, output array, and gas usage of precompile.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*) -> (output_len: felt, output: felt*, gas_used: felt) {
        alloc_locals;

        let x0: BigInt3 = Helpers.bytes32_to_bigint(input);
        let y0: BigInt3 = Helpers.bytes32_to_bigint(input + G1POINT_BYTES_LEN);
        let x1: BigInt3 = Helpers.bytes32_to_bigint(input + G1POINT_BYTES_LEN * 2);
        let y1: BigInt3 = Helpers.bytes32_to_bigint(input + G1POINT_BYTES_LEN * 3);

        with_attr error_message("Kakarot: ec_add failed") {
            let point0: G1Point = G1Point(x0, y0);
            let point1: G1Point = G1Point(x1, y1);
            let result: G1Point = ALT_BN128.ec_add(point0, point1);
        }

        let (bytes_x_len, output: felt*) = Helpers.bigint_to_bytes_array(result.x);
        let (bytes_y_len, bytes_y: felt*) = Helpers.bigint_to_bytes_array(result.y);
        // We fill `output + bytes_x_len` ptr with `bytes_y` elements
        Helpers.fill_array(bytes_y_len, bytes_y, output + bytes_x_len);

        return (G1POINT_BYTES_LEN * 2, output, GAS_COST_EC_ADD);
    }
}
