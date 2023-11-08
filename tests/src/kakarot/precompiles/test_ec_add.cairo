// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from utils.utils import Helpers
from utils.alt_bn128.alt_bn128_g1 import ALT_BN128, G1Point
from kakarot.precompiles.ecadd import PrecompileEcAdd
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.utils.helpers import TestHelpers

const G1POINT_BYTES_LEN = 32;

@external
func test__ecadd_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // Given
    alloc_locals;

    let x0: BigInt3 = Helpers.bytes32_to_bigint(calldata);
    let y0: BigInt3 = Helpers.bytes32_to_bigint(calldata + G1POINT_BYTES_LEN);
    let x1: BigInt3 = Helpers.bytes32_to_bigint(calldata + G1POINT_BYTES_LEN * 2);
    let y1: BigInt3 = Helpers.bytes32_to_bigint(calldata + G1POINT_BYTES_LEN * 3);

    // When
    let point0: G1Point = G1Point(x0, y0);
    let point1: G1Point = G1Point(x1, y1);
    let (expected_point: G1Point) = ALT_BN128.ec_add(point0, point1);
    let (bytes_expected_x_len, bytes_expected_result: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.x
    );
    let (bytes_expected_y_len, bytes_expected_y: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.y
    );
    // We fill `bytes_expected_result + bytes_expected_x_len` ptr with `bytes_expected_y` elements
    Helpers.fill_array(
        bytes_expected_y_len, bytes_expected_y, bytes_expected_result + bytes_expected_x_len
    );
    let (output_len, output: felt*, gas_used, reverted) = PrecompileEcAdd.run(
        PrecompileEcAdd.PRECOMPILE_ADDRESS, calldata_len, calldata
    );

    // Then
    TestHelpers.assert_array_equal(
        array_0_len=bytes_expected_x_len + bytes_expected_y_len,
        array_0=bytes_expected_result,
        array_1_len=output_len,
        array_1=output,
    );

    return ();
}
