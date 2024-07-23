from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul,
    uint256_le,
    uint256_pow2,
    SHIFT,
    ALL_ONES,
    uint256_lt,
    uint256_not,
)
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math_cmp import is_nn

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

// ! The following functions are taken from starkware's cairo common library
// ! to use the optimized uint256_add and uint256_sub, with inlined uint256_check

// Returns 1 if the first signed integer is less than the second signed integer.
func uint256_signed_lt{range_check_ptr}(a: Uint256, b: Uint256) -> (res: felt) {
    alloc_locals;
    let (a, _) = uint256_add(a, Uint256(low=0, high=2 ** 127));
    let (b, _) = uint256_add(b, Uint256(low=0, high=2 ** 127));
    return uint256_lt(a, b);
}

// Unsigned integer division between two integers. Returns the quotient and the remainder.
// Conforms to EVM specifications: division by 0 yields 0.
func uint256_unsigned_div_rem{range_check_ptr}(a: Uint256, div: Uint256) -> (
    quotient: Uint256, remainder: Uint256
) {
    alloc_locals;

    // If div == 0, return (0, 0).
    if (div.low + div.high == 0) {
        return (quotient=Uint256(0, 0), remainder=Uint256(0, 0));
    }

    // Guess the quotient and the remainder.
    local quotient: Uint256;
    local remainder: Uint256;
    %{
        a = (ids.a.high << 128) + ids.a.low
        div = (ids.div.high << 128) + ids.div.low
        quotient, remainder = divmod(a, div)

        ids.quotient.low = quotient & ((1 << 128) - 1)
        ids.quotient.high = quotient >> 128
        ids.remainder.low = remainder & ((1 << 128) - 1)
        ids.remainder.high = remainder >> 128
    %}
    [range_check_ptr] = quotient.low;
    [range_check_ptr + 1] = quotient.high;
    [range_check_ptr + 2] = remainder.low;
    [range_check_ptr + 3] = remainder.high;
    let range_check_ptr = range_check_ptr + 4;
    let (res_mul, carry) = uint256_mul(quotient, div);
    assert carry = Uint256(0, 0);

    let (check_val, add_carry) = uint256_add(res_mul, remainder);
    assert check_val = a;
    assert add_carry = 0;

    let (is_valid) = uint256_lt(remainder, div);
    assert is_valid = 1;
    return (quotient=quotient, remainder=remainder);
}

// Computes:
// 1. The integer division `(a * b) // div` (as a 512-bit number).
// 2. The remainder `(a * b) modulo div`.
// Assumption: div != 0.
func uint256_mul_div_mod{range_check_ptr}(a: Uint256, b: Uint256, div: Uint256) -> (
    quotient_low: Uint256, quotient_high: Uint256, remainder: Uint256
) {
    alloc_locals;

    // Compute a * b (512 bits).
    let (ab_low, ab_high) = uint256_mul(a, b);

    // Guess the quotient and remainder of (a * b) / d.
    local quotient_low: Uint256;
    local quotient_high: Uint256;
    local remainder: Uint256;

    %{
        a = (ids.a.high << 128) + ids.a.low
        b = (ids.b.high << 128) + ids.b.low
        div = (ids.div.high << 128) + ids.div.low
        quotient, remainder = divmod(a * b, div)

        ids.quotient_low.low = quotient & ((1 << 128) - 1)
        ids.quotient_low.high = (quotient >> 128) & ((1 << 128) - 1)
        ids.quotient_high.low = (quotient >> 256) & ((1 << 128) - 1)
        ids.quotient_high.high = quotient >> 384
        ids.remainder.low = remainder & ((1 << 128) - 1)
        ids.remainder.high = remainder >> 128
    %}

    // Compute x = quotient * div + remainder.
    [range_check_ptr] = quotient_high.low;
    [range_check_ptr + 1] = quotient_high.high;
    let range_check_ptr = range_check_ptr + 2;
    let (quotient_mod10, quotient_mod11) = uint256_mul(quotient_high, div);

    [range_check_ptr] = quotient_low.low;
    [range_check_ptr + 1] = quotient_low.high;
    let range_check_ptr = range_check_ptr + 2;
    let (quotient_mod00, quotient_mod01) = uint256_mul(quotient_low, div);
    // Since x should equal a * b, the high 256 bits must be zero.
    assert quotient_mod11 = Uint256(0, 0);

    // The low 256 bits of x must be ab_low.
    [range_check_ptr] = remainder.low;
    [range_check_ptr + 1] = remainder.high;
    let range_check_ptr = range_check_ptr + 2;
    let (x0, carry0) = uint256_add(quotient_mod00, remainder);
    assert x0 = ab_low;

    let (x1, carry1) = uint256_add(quotient_mod01, quotient_mod10);
    assert carry1 = 0;
    let (x1, carry2) = uint256_add(x1, Uint256(low=carry0, high=0));
    assert carry2 = 0;

    assert x1 = ab_high;

    // Verify that 0 <= remainder < div.
    let (is_valid) = uint256_lt(remainder, div);
    assert is_valid = 1;

    return (quotient_low=quotient_low, quotient_high=quotient_high, remainder=remainder);
}

// Returns the negation of an integer.
// Note that the negation of -2**255 is -2**255.
func uint256_neg{range_check_ptr}(a: Uint256) -> (res: Uint256) {
    let (not_num) = uint256_not(a);
    let (res, _) = uint256_add(not_num, Uint256(low=1, high=0));
    return (res=res);
}

// Conditionally negates an integer.
func uint256_cond_neg{range_check_ptr}(a: Uint256, should_neg) -> (res: Uint256) {
    if (should_neg != 0) {
        return uint256_neg(a);
    } else {
        return (res=a);
    }
}

// Signed integer division between two integers. Returns the quotient and the remainder.
// Conforms to EVM specifications.
// See ethereum yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf, page 29).
// Note that the remainder may be negative if one of the inputs is negative and that
// (-2**255) / (-1) = -2**255 because 2*255 is out of range.
func uint256_signed_div_rem{range_check_ptr}(a: Uint256, div: Uint256) -> (
    quot: Uint256, rem: Uint256
) {
    alloc_locals;

    // When div=-1, simply return -a.
    if (div.low == SHIFT - 1 and div.high == SHIFT - 1) {
        let (quot) = uint256_neg(a);
        return (quot, cast((0, 0), Uint256));
    }

    // Take the absolute value of a.
    local a_sign = is_nn(a.high - 2 ** 127);
    local range_check_ptr = range_check_ptr;
    let (local a) = uint256_cond_neg(a, should_neg=a_sign);

    // Take the absolute value of div.
    local div_sign = is_nn(div.high - 2 ** 127);
    local range_check_ptr = range_check_ptr;
    let (div) = uint256_cond_neg(div, should_neg=div_sign);

    // Unsigned division.
    let (local quot, local rem) = uint256_unsigned_div_rem(a, div);
    local range_check_ptr = range_check_ptr;

    // Fix the remainder according to the sign of a.
    let (rem) = uint256_cond_neg(rem, should_neg=a_sign);

    // Fix the quotient according to the signs of a and div.
    if (a_sign == div_sign) {
        return (quot=quot, rem=rem);
    }
    let (local quot_neg) = uint256_neg(quot);

    return (quot=quot_neg, rem=rem);
}

// Computes the logical right shift of a uint256 integer.
func uint256_shr{range_check_ptr}(a: Uint256, b: Uint256) -> (res: Uint256) {
    let (c) = uint256_pow2(b);
    let (res, _) = uint256_unsigned_div_rem(a, c);
    return (res=res);
}

// ! End of functions taken from starkware's cairo common library

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

// @notice Return true if both integers are equal.
// @dev Same as the one from starkware's cairo common library, but without the useless range_check arg
func uint256_eq(a: Uint256, b: Uint256) -> (res: felt) {
    if (a.high != b.high) {
        return (res=0);
    }
    if (a.low != b.low) {
        return (res=0);
    }
    return (res=1);
}
