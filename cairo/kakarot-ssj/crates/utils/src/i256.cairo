use core::num::traits::Bounded;
use crate::constants::POW_2_127;

/// Represents a signed 256-bit integer.
#[derive(Copy, Drop, PartialEq)]
pub struct i256 {
    /// The underlying unsigned 256-bit value.
    pub value: u256,
}


pub impl U256IntoI256 of Into<u256, i256> {
    #[inline(always)]
    fn into(self: u256) -> i256 {
        i256 { value: self }
    }
}

pub impl I256IntoU256 of Into<i256, u256> {
    #[inline(always)]
    fn into(self: i256) -> u256 {
        self.value
    }
}

pub impl I256PartialOrd of PartialOrd<i256> {
    #[inline(always)]
    fn le(lhs: i256, rhs: i256) -> bool {
        !(rhs < lhs)
    }

    #[inline(always)]
    fn ge(lhs: i256, rhs: i256) -> bool {
        !(lhs < rhs)
    }

    #[inline(always)]
    fn lt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.value.high < POW_2_127;
        let rhs_positive = rhs.value.high < POW_2_127;

        if (lhs_positive != rhs_positive) {
            !lhs_positive
        } else {
            lhs.value < rhs.value
        }
    }

    #[inline(always)]
    fn gt(lhs: i256, rhs: i256) -> bool {
        let lhs_positive = lhs.value.high < POW_2_127;
        let rhs_positive = rhs.value.high < POW_2_127;

        if (lhs_positive != rhs_positive) {
            lhs_positive
        } else {
            lhs.value > rhs.value
        }
    }
}

pub impl I256Div of Div<i256> {
    fn div(lhs: i256, rhs: i256) -> i256 {
        let (q, _) = i256_signed_div_rem(lhs, rhs.value.try_into().expect('Division by 0'));
        return q.into();
    }
}

pub impl I256Rem of Rem<i256> {
    fn rem(lhs: i256, rhs: i256) -> i256 {
        let (_, r) = i256_signed_div_rem(lhs, rhs.value.try_into().expect('Division by 0'));
        return r.into();
    }
}

/// Performs signed integer division between two integers.
///
/// This function conforms to EVM specifications, except that the type system enforces div != zero.
/// See ethereum yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf, page 29).
///
/// Note:
/// - The remainder may be negative if one of the inputs is negative.
/// - (-2**255) / (-1) = -2**255 because 2**255 is out of range.
///
/// # Arguments
///
/// * `a` - The dividend.
/// * `div` - The divisor, passed as a signed NonZero<u256>.
///
/// # Returns
///
/// A tuple containing (quotient, remainder) of the signed division of `a` by `div`.
fn i256_signed_div_rem(a: i256, div: NonZero<u256>) -> (i256, i256) {
    let mut div = i256 { value: div.into() };

    // When div=-1, simply return -a.
    if div.value == Bounded::<u256>::MAX {
        return (i256_neg(a).into(), 0_u256.into());
    }

    // Take the absolute value of a and div.
    // Checks the MSB bit sign for a 256-bit integer
    let a_positive = a.value.high < POW_2_127;
    let a = if a_positive {
        a
    } else {
        i256_neg(a).into()
    };

    let div_positive = div.value.high < POW_2_127;
    div = if div_positive {
        div
    } else {
        i256_neg(div).into()
    };

    // Compute the quotient and remainder.
    // Can't panic as zero case is handled in the first instruction
    let (quot, rem) = DivRem::div_rem(a.value, div.value.try_into().unwrap());

    // Restore remainder sign.
    let rem = if a_positive {
        rem.into()
    } else {
        i256_neg(rem.into())
    };

    // If the signs of a and div are the same, return the quotient and remainder.
    if a_positive == div_positive {
        return (quot.into(), rem.into());
    }

    // Otherwise, return the negation of the quotient and the remainder.
    (i256_neg(quot.into()), rem.into())
}

/// Computes the negation of an i256 integer.
///
/// Note that the negation of -2**255 is -2**255.
///
/// # Arguments
///
/// * `a` - The i256 value to negate.
///
/// # Returns
///
/// The negation of the input value.
fn i256_neg(a: i256) -> i256 {
    // If a is 0, adding one to its bitwise NOT will overflow and return 0.
    if a.value == 0 {
        return 0_u256.into();
    }
    (~a.value + 1).into()
}

#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use crate::i256::{i256, i256_neg, i256_signed_div_rem};

    const MAX_SIGNED_VALUE: u256 =
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    const MIN_SIGNED_VALUE: u256 =
        0x8000000000000000000000000000000000000000000000000000000000000000;

    #[test]
    fn test_i256_eq() {
        let val: i256 = 1_u256.into();

        assert(val == 1_u256.into(), 'i256 should be eq');
    }

    #[test]
    fn test_i256_ne() {
        let val: i256 = 1_u256.into();

        assert(val != 2_u256.into(), 'i256 should be ne');
    }

    #[test]
    fn test_i256_positive() {
        let val: i256 = MAX_SIGNED_VALUE.into();

        assert(val > 0_u256.into(), 'i256 should be positive');
    }

    #[test]
    fn test_i256_negative() {
        let val: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(val < 0_u256.into(), 'i256 should be negative');
    }

    #[test]
    fn test_lt_positive_positive() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 2_u256.into();

        assert(lhs < rhs, 'lhs should be lt rhs');
    }

    #[test]
    fn test_lt_negative_negative() {
        let lhs: i256 = (Bounded::<u256>::MAX - 1).into(); // -2
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(lhs < rhs, 'lhs should be lt rhs');
    }

    #[test]
    fn test_lt_negative_positive() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = 1_u256.into();

        assert(lhs < rhs, 'lhs should be lt rhs');
    }

    #[test]
    fn test_lt_positive_negative() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(!(lhs < rhs), 'lhs should not be lt rhs');
    }

    #[test]
    fn test_lt_equals() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(!(lhs < rhs), 'lhs should not be lt rhs');
    }

    #[test]
    fn test_le_positive_positive() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 2_u256.into();

        assert(lhs <= rhs, 'lhs should be le rhs');
    }

    #[test]
    fn test_le_negative_negative() {
        let lhs: i256 = (Bounded::<u256>::MAX - 1).into(); // -2
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(lhs <= rhs, 'lhs should be le rhs');
    }

    #[test]
    fn test_le_negative_positive() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = 1_u256.into();

        assert(lhs <= rhs, 'lhs should be le rhs');
    }

    #[test]
    fn test_le_positive_negative() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(!(lhs <= rhs), 'lhs should not be le rhs');
    }

    #[test]
    fn test_le_equals() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(lhs <= rhs, 'lhs should be le rhs');
    }

    #[test]
    fn test_gt_positive_positive() {
        let lhs: i256 = 2_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(lhs > rhs, 'lhs should be gt rhs');
    }

    #[test]
    fn test_gt_negative_negative() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = (Bounded::<u256>::MAX - 1).into(); // -2

        assert(lhs > rhs, 'lhs should be gt rhs');
    }

    #[test]
    fn test_gt_negative_positive() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = 1_u256.into();

        assert(!(lhs > rhs), 'lhs should not be gt rhs');
    }

    #[test]
    fn test_gt_positive_negative() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(lhs > rhs, 'lhs should be gt rhs');
    }

    #[test]
    fn test_gt_equals() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(!(lhs > rhs), 'lhs should not be gt rhs');
    }

    #[test]
    fn test_ge_positive_positive() {
        let lhs: i256 = 2_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(lhs >= rhs, 'lhs should be ge rhs');
    }

    #[test]
    fn test_ge_negative_negative() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = (Bounded::<u256>::MAX - 1).into(); // -2

        assert(lhs >= rhs, 'lhs should be ge rhs');
    }

    #[test]
    fn test_ge_negative_positive() {
        let lhs: i256 = Bounded::<u256>::MAX.into(); // -1
        let rhs: i256 = 1_u256.into();

        assert(!(lhs >= rhs), 'lhs should not be ge rhs');
    }

    #[test]
    fn test_ge_positive_negative() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = Bounded::<u256>::MAX.into(); // -1

        assert(lhs >= rhs, 'lhs should be ge rhs');
    }

    #[test]
    fn test_ge_equals() {
        let lhs: i256 = 1_u256.into();
        let rhs: i256 = 1_u256.into();

        assert(lhs >= rhs, 'lhs should be ge rhs');
    }

    #[test]
    fn test_i256_neg() {
        let max_u256 = Bounded::<u256>::MAX;
        let x = i256_neg(1_u256.into());
        // 0000_0001 turns into 1111_1110 + 1 = 1111_1111
        assert(x.value.low == max_u256.low && x.value.high == max_u256.high, 'i256_neg failed.');

        let x = i256_neg(0_u256.into());
        // 0000_0000 turns into 1111_1111 + 1 = 0000_0000
        assert(x == 0_u256.into(), 'i256_neg with zero failed.');

        let x = max_u256;
        // 1111_1111 turns into 0000_0000 + 1 = 0000_0001
        assert(i256_neg(x.into()) == 1_u256.into(), 'i256_neg with max_u256 failed.');
    }

    #[test]
    fn test_signed_div_rem() {
        let max_u256 = Bounded::<u256>::MAX;
        let max_i256 = i256 { value: max_u256 };
        // Division by -1
        assert(
            i256_signed_div_rem(
                i256 { value: 1 }, max_u256.try_into().unwrap()
            ) == (max_i256, 0_u256.into()),
            'Division by -1 failed - 1.'
        ); // 1 / -1 == -1
        assert(
            i256_signed_div_rem(
                max_i256, max_u256.try_into().unwrap()
            ) == (i256 { value: 1 }, 0_u256.into()),
            'Division by -1 failed - 2.'
        ); // -1 / -1 == 1
        assert(
            i256_signed_div_rem(
                i256 { value: 0 }, max_u256.try_into().unwrap()
            ) == (i256 { value: 0 }, 0_u256.into()),
            'Division by -1 failed - 3.'
        ); // 0 / -1 == 0

        // Simple Division
        assert(
            i256_signed_div_rem(
                i256 { value: 10 }, 2_u256.try_into().unwrap()
            ) == (i256 { value: 5 }, 0_u256.into()),
            'Simple Division failed - 1.'
        ); // 10 / 2 == 5
        assert(
            i256_signed_div_rem(
                i256 { value: 10 }, 3_u256.try_into().unwrap()
            ) == (i256 { value: 3 }, 1_u256.into()),
            'Simple Division failed - 2.'
        ); // 10 / 3 == 3 remainder 1

        // Dividing a Negative Number
        assert(
            i256_signed_div_rem(max_i256, 1_u256.try_into().unwrap()) == (max_i256, 0_u256.into()),
            'Dividing a neg num failed - 1.'
        ); // -1 / 1 == -1
        assert(
            i256_signed_div_rem(
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
                0x2_u256.try_into().unwrap()
            ) == (max_i256, 0_u256.into()),
            'Dividing a neg num failed - 2.'
        ); // -2 / 2 == -1
        // - 2**255 / 2 == - 2**254
        assert(
            i256_signed_div_rem(
                i256 { value: 0x8000000000000000000000000000000000000000000000000000000000000000 },
                0x2_u256.try_into().unwrap()
            ) == (
                i256 { value: 0xc000000000000000000000000000000000000000000000000000000000000000 },
                0_u256.into()
            ),
            'Dividing a neg num failed - 3.'
        );

        // Dividing by a Negative Number
        assert(
            i256_signed_div_rem(
                i256 { value: 0x4 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE_u256
                    .try_into()
                    .unwrap()
            ) == (
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
                0_u256.into()
            ),
            'Div by a neg num failed - 1.'
        ); // 4 / -2 == -2
        assert(
            i256_signed_div_rem(
                i256 { value: MAX_SIGNED_VALUE },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                    .try_into()
                    .unwrap()
            ) == (i256 { value: (MIN_SIGNED_VALUE + 1) }, 0_u256.into()),
            'Div by a neg num failed - 2.'
        ); // MAX_VALUE (2**255 -1) / -1 == MIN_VALUE + 1
        assert(
            i256_signed_div_rem(
                i256 { value: 0x1 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                    .try_into()
                    .unwrap()
            ) == (
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF },
                0_u256.into()
            ),
            'Div by a neg num failed - 3.'
        ); // 1 / -1 == -1

        // Both Dividend and Divisor Negative
        assert(
            i256_signed_div_rem(
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFB_u256
                    .try_into()
                    .unwrap()
            ) == (i256 { value: 2 }, 0_u256.into()),
            'Div w/ both neg num failed - 1.'
        ); // -10 / -5 == 2
        assert(
            i256_signed_div_rem(
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5_u256
                    .try_into()
                    .unwrap()
            ) == (
                i256 { value: 0 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6_u256.into()
            ),
            'Div w/ both neg num failed - 2.'
        ); // -10 / -11 == 0 remainder -10

        // Division with Remainder
        assert(
            i256_signed_div_rem(
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF9 },
                0x3_u256.try_into().unwrap()
            ) == (
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into()
            ),
            'Div with rem failed - 1.'
        ); // -7 / 3 == -2 remainder -1
        assert(
            i256_signed_div_rem(
                i256 { value: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF },
                0x2_u256.try_into().unwrap()
            ) == (
                i256 { value: 0 },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256.into()
            ),
            'Div with rem failed - 2.'
        ); // -1 / 2 == 0 remainder -1

        // Edge Case: Dividing Minimum Value by -1
        assert(
            i256_signed_div_rem(
                i256 { value: MIN_SIGNED_VALUE },
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF_u256
                    .try_into()
                    .unwrap()
            ) == (i256 { value: MIN_SIGNED_VALUE }, 0_u256.into()),
            'Div w/ both neg num failed - 3.'
        ); // MIN / -1 == MIN because 2**255 is out of range
    }

    #[test]
    #[should_panic(expected: ('Option::unwrap failed.',))]
    fn test_signed_div_rem_by_zero() {
        //     Zero Division
        assert(
            i256_signed_div_rem(
                i256 { value: 0 }, 0_u256.try_into().unwrap()
            ) == (i256 { value: 0 }, i256 { value: 0 }),
            'Zero Division failed - 1.'
        );
    }
}
