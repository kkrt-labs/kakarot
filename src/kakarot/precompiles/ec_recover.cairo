%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.cairo_secp.bigint import BigInt3
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
)

from utils.utils import Helpers
from utils.array import slice
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

        let (input_padded) = alloc();
        slice(input_padded, input_len, input, 0, 4 * 32);

        let hash = Helpers.bytes32_to_bigint(input_padded);
        let v_uint256 = Helpers.bytes32_to_uint256(input_padded + 32);
        let v = Helpers.uint256_to_felt(v_uint256);

        if ((v - 27) * (v - 28) != 0) {
            let (output) = alloc();
            return (0, output, GAS_COST_EC_RECOVER, 0);
        }

        let r = Helpers.bytes32_to_bigint(input_padded + 32 * 2);
        let s = Helpers.bytes32_to_bigint(input_padded + 32 * 3);

        // v - 27, see recover_public_key comment
        let (public_key_point) = recover_public_key(hash, r, s, v - 27);
        let (is_public_key_invalid) = EcRecoverHelpers.ec_point_equal(
            public_key_point, EcPoint(BigInt3(0, 0, 0), BigInt3(0, 0, 0))
        );

        if (is_public_key_invalid != FALSE) {
            let (output) = alloc();
            return (0, output, GAS_COST_EC_RECOVER, 0);
        }

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

namespace EcRecoverHelpers {
    func ec_point_equal(point_0: EcPoint, point_1: EcPoint) -> (is_equal: felt) {
        if (point_0.x.d0 == point_1.x.d0 and point_0.y.d0 == point_1.y.d0 and
            point_0.x.d1 == point_1.x.d1 and point_0.y.d1 == point_1.y.d1 and
            point_0.x.d2 == point_1.x.d2 and point_0.y.d2 == point_1.y.d2) {
            return (is_equal=1);
        }
        return (is_equal=0);
    }
}
