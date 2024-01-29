%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

from utils.utils import Helpers
from utils.alt_bn128.alt_bn128_g1 import ALT_BN128, G1Point
from kakarot.precompiles.ecmul import PrecompileEcMul
from tests.utils.helpers import TestHelpers

const G1POINT_BYTES_LEN = 32;

func test__ecmul_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let x: BigInt3 = uint256_to_bigint(Uint256(1, 0));
    let y: BigInt3 = uint256_to_bigint(Uint256(2, 0));
    let scalar: BigInt3 = uint256_to_bigint(Uint256(2, 0));
    let (x_bytes_len, x_bytes: felt*) = Helpers.bigint_to_bytes_array(x);
    let (y_bytes_len, y_bytes: felt*) = Helpers.bigint_to_bytes_array(y);
    let (scalar_bytes_len, scalar_bytes: felt*) = Helpers.bigint_to_bytes_array(scalar);

    // When
    let point: G1Point = G1Point(x, y);
    let (expected_point: G1Point) = ALT_BN128.ec_mul(point, scalar);
    let (bytes_expected_x_len, bytes_expected_result: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.x
    );
    let (bytes_expected_y_len, bytes_expected_y: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.y
    );
    memcpy(bytes_expected_result + bytes_expected_x_len, bytes_expected_y, bytes_expected_y_len);
    let input_len = 96;
    let (input: felt*) = alloc();
    memcpy(input, x_bytes, x_bytes_len);
    memcpy(input + 32, y_bytes, y_bytes_len);
    memcpy(input + 64, scalar_bytes, scalar_bytes_len);
    let (output_len, output: felt*, gas_used, reverted) = PrecompileEcMul.run(
        PrecompileEcMul.PRECOMPILE_ADDRESS, input_len, input
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
