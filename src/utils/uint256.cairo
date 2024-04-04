from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
    uint256_le,
    uint256_pow2,
    SHIFT,
    ALL_ONES,
)
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import FALSE

// Adds two integers. Returns the result as a 256-bit integer and the (1-bit) carry.
// Strictly equivalent and faster version of common.uint256.uint256_add using the same whitelisted hint.
func uint256_add{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256, carry: felt) {
    alloc_locals;
    local carry_low: felt;
    local carry_high: felt;
    %{
        sum_low = ids.a.low + ids.b.low
        ids.carry_low = 1 if sum_low >= ids.SHIFT else 0
        sum_high = ids.a.high + ids.b.high + ids.carry_low
        ids.carry_high = 1 if sum_high >= ids.SHIFT else 0
    %}

    if (carry_low != 0) {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1 - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    } else {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 1);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res, 0);
        }
    }
}

// Subtracts two integers. Returns the result as a 256-bit integer.
// Strictly equivalent and faster version of common.uint256.uint256_sub using uint256_add's whitelisted hint.
func uint256_sub{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256) {
    alloc_locals;
    // Reference "b" as -b.
    local b: Uint256 = Uint256(ALL_ONES - b.low + 1, ALL_ONES - b.high);
    // Computes a + (-b)
    local carry_low: felt;
    local carry_high: felt;
    %{
        sum_low = ids.a.low + ids.b.low
        ids.carry_low = 1 if sum_low >= ids.SHIFT else 0
        sum_high = ids.a.high + ids.b.high + ids.carry_low
        ids.carry_high = 1 if sum_high >= ids.SHIFT else 0
    %}

    if (carry_low != 0) {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1 - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low - SHIFT, high=a.high + b.high + 1);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        }
    } else {
        if (carry_high != 0) {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high - SHIFT);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        } else {
            tempvar range_check_ptr = range_check_ptr + 2;
            tempvar res = Uint256(low=a.low + b.low, high=a.high + b.high);
            assert [range_check_ptr - 2] = res.low;
            assert [range_check_ptr - 1] = res.high;
            return (res,);
        }
    }
}

// @notice Internal exponentiation of two 256-bit integers.
// @dev The result is modulo 2^256.
// @param value - The base.
// @param exponent - The exponent.
// @return The result of the exponentiation.
func uint256_exp{range_check_ptr}(value: Uint256, exponent: Uint256) -> Uint256 {
    let one = Uint256(1, 0);
    let zero = Uint256(0, 0);

    let (exponent_is_zero) = uint256_eq(exponent, zero);
    if (exponent_is_zero != FALSE) {
        return one;
    }
    let (exponent_minus_one) = uint256_sub(exponent, one);
    let pow = uint256_exp(value, exponent_minus_one);
    let (res, _) = uint256_mul(value, pow);
    return res;
}

// @notice Extend a signed number which fits in N bytes to 32 bytes.
// @param x The number to be sign extended.
// @param byte_num The size in bytes minus one of x to consider.
// @returns x if byteNum > 31, or x interpreted as a signed number with sign-bit at (byte_num*8+7), extended to the full 256 bits
func uint256_signextend{range_check_ptr}(x: Uint256, byte_num: Uint256) -> Uint256 {
    alloc_locals;
    let (byte_num_gt_word_size) = uint256_le(Uint256(32, 0), byte_num);
    if (byte_num_gt_word_size != 0) {
        return x;
    }

    let sign_bit_position = byte_num.low * 8 + 7;

    let (s) = uint256_pow2(Uint256(sign_bit_position, 0));
    let (sign_bit, value) = uint256_unsigned_div_rem(x, s);
    let (_, x_is_negative) = uint256_unsigned_div_rem(sign_bit, Uint256(2, 0));

    if (x_is_negative.low == 0) {
        return value;
    }

    let (mask) = uint256_sub(s, Uint256(1, 0));
    let max_uint256 = Uint256(2 ** 128 - 1, 2 ** 128 - 1);
    let (padding) = uint256_sub(max_uint256, mask);
    let (value, _) = uint256_add(value, padding);
    return value;
}

// @notice Internal fast exponentiation of two 256-bit integers.
// @dev The result is modulo 2^256.
// @param value - The base.
// @param exponent - The exponent.
// @return The result of the exponentiation.
func uint256_fast_exp{range_check_ptr}(value: Uint256, exponent: Uint256) -> Uint256 {
    alloc_locals;

    let one = Uint256(1, 0);
    let zero = Uint256(0, 0);

    let (exponent_is_zero) = uint256_eq(exponent, zero);
    if (exponent_is_zero != FALSE) {
        return one;
    }

    let (exponent_is_one) = uint256_eq(exponent, one);
    if (exponent_is_one != FALSE) {
        return value;
    }

    let (half_exponent, is_odd) = uint256_unsigned_div_rem(exponent, Uint256(2, 0));
    let pow = uint256_fast_exp(value, half_exponent);

    if (is_odd.low != FALSE) {
        let (res, _) = uint256_mul(pow, pow);
        let (res, _) = uint256_mul(res, value);
        return res;
    }

    let pow = uint256_fast_exp(value, half_exponent);
    let (res, _) = uint256_mul(pow, pow);
    return res;
}

// @notice Converts a 256-bit unsigned integer to a 160-bit unsigned integer.
// @dev The result is modulo 2^160.
// @param x The 256-bit unsigned integer.
// @return The 160-bit unsigned integer.
func uint256_to_uint160{range_check_ptr}(x: Uint256) -> felt {
    let (_, high) = unsigned_div_rem(x.high, 2 ** 32);
    return x.low + high * 2 ** 128;
}
