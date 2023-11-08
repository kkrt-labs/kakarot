// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
)

// Internal dependencies
from utils.utils import Helpers
from kakarot.errors import Errors

// @title EcRecover Precompile related functions.
// @notice This file contains the logic required to run the ec_recover precompile
// using Starkware's cairo_secp library
// @author @clementwalter
// @custom:namespace PrecompileEcRecover
namespace PrecompileEcRecover {
    const PRECOMPILE_ADDRESS = 0x01;
    const GAS_COST_EC_RECOVER = 3000;

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

        if (input_len != 4 * 32) {
            let (revert_reason_len, revert_reason) = Errors.precompileInputError();
            return (revert_reason_len, revert_reason, 0, 1);
        }

        let hash = Helpers.bytes32_to_bigint(input);
        let v_uint256 = Helpers.bytes32_to_uint256(input + 32);
        let v = Helpers.uint256_to_felt(v_uint256);

        if ((v - 27) * (v - 28) != 0) {
            let (revert_reason_len, revert_reason) = Errors.precompileFlagError();
            return (revert_reason_len, revert_reason, 0, 1);
        }

        let r = Helpers.bytes32_to_bigint(input + 32 * 2);
        let s = Helpers.bytes32_to_bigint(input + 32 * 3);

        // v - 27, see recover_public_key comment
        let (public_key_point) = recover_public_key(hash, r, s, v - 27);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;
        with keccak_ptr {
            let (public_address) = public_key_point_to_eth_address(public_key_point);
            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let (output) = alloc();
        Helpers.split_word(public_address, 32, output);

        return (32, output, GAS_COST_EC_RECOVER, 0);
    }
}
