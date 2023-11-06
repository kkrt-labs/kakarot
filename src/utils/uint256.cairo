from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_le, uint256_sub, uint256_mul
from starkware.cairo.common.bool import FALSE

// @notice Internal exponentiation of two 256-bit integers.
// @dev The result is modulo 2^256.
// @param a The base.
// @param b The exponent.
// @return The result of the exponentiation.
func uint256_exp{range_check_ptr}(a: Uint256, b: Uint256) -> Uint256 {
    let one_uint = Uint256(1, 0);
    let zero_uint = Uint256(0, 0);

    let (is_b_one) = uint256_eq(b, zero_uint);
    if (is_b_one != FALSE) {
        return one_uint;
    }
    let (is_b_ge_than_one) = uint256_le(zero_uint, b);
    if (is_b_ge_than_one == FALSE) {
        return zero_uint;
    }
    let (b_minus_one) = uint256_sub(b, one_uint);
    let pow = uint256_exp(a, b_minus_one);
    let (res, _) = uint256_mul(a, pow);
    return res;
}
