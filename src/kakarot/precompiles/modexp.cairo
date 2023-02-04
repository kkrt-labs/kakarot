// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers
from utils.modexp.modexp_utils import ModExpHelpers

// @title ModExp Precompile related functions.
// @notice This file contains the logic required to run the modexp precompile
// @author @dragan2234
// @custom:namespace PrecompileModExp
namespace PrecompileModExp {
    const PRECOMPILE_ADDRESS = 0x05;
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
        let b_size: Uint256 = Helpers.bytes32_to_uint256(input);
        let e_size: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN);
        let m_size: Uint256 = Helpers.bytes32_to_uint256(input + MOD_EXP_BYTES_LEN * 2);
        let b: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3, b_size.low);
        let e: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3 + b_size.low, e_size.low);
        let m: Uint256 = Helpers.bytes_i_to_uint256(input + MOD_EXP_BYTES_LEN * 3 + b_size.low + e_size.low, m_size.low);

        with_attr error_message("Kakarot: modexp failed") {
            let (result) = ModExpHelpers.uint256_expmod(b,e,m);
        }

        let (bytes_result_len, output: felt*) = Helpers.uint256_to_bytes_array(result);
        let (gas_cost) = ModExpHelpers.calculate_modexp_gas(b_size, m_size, e_size, e);
        return (output_len=bytes_result_len, output=output, gas_used=gas_cost);
    }
}
