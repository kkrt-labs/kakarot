%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import RC_BOUND
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.cairo_secp.bigint import BigInt3
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
)
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.cairo_secp.bigint import bigint_to_uint256
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256s

from utils.utils import Helpers
from utils.array import slice, pad_end
from kakarot.errors import Errors
from kakarot.storages import Kakarot_cairo1_helpers_class_hash
from kakarot.interfaces.interfaces import ICairo1Helpers

// @title P256Verify precompile related functions.
// @notice This file contains the logic required to run the ec_recover precompile
// using Starkware's cairo_secp library
// @author @clementwalter
// @custom:namespace PrecompileEcRecover
namespace PrecompileP256Verify {
    const PRECOMPILE_ADDRESS = 0x100;
    const GAS_COST_P256_VERIFY = 3450;

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

        pad_end(input_len, input, 160);

        let msg_hash = Helpers.bytes32_to_uint256(input);
        let r = Helpers.bytes32_to_uint256(input + 32);
        let s = Helpers.bytes32_to_uint256(input + 64);
        let x = Helpers.bytes32_to_uint256(input + 96);
        let y = Helpers.bytes32_to_uint256(input + 128);

        let (helpers_class) = Kakarot_cairo1_helpers_class_hash.read();

        let (is_valid) = ICairo1Helpers.library_call_verify_signature_secp256r1(
            class_hash=helpers_class, msg_hash=msg_hash, r=r, s=s, x=x, y=y
        );

        let (output) = alloc();
        if (is_valid == 0) {
            return (0, output, GAS_COST_P256_VERIFY, 0);
        }

        assert output[0] = 1;
        return (1, output, GAS_COST_P256_VERIFY, 0);
    }
}
