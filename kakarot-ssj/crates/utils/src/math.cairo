use core::integer::{u512};
use core::num::traits::{Zero, One, BitSize, OverflowingAdd, OverflowingMul};
use core::panic_with_felt252;
use core::traits::{BitAnd};

// === Exponentiation ===

pub trait Exponentiation<T> {
    /// Raise a number to a power.
    ///
    /// # Arguments
    ///
    /// * `self` - The base number
    /// * `exponent` - The exponent to raise the base to
    ///
    /// # Returns
    ///
    /// The result of raising `self` to the power of `exponent`
    ///
    /// # Panics
    ///
    /// Panics if the result overflows the type T.
    fn pow(self: T, exponent: T) -> T;
}

impl ExponentiationImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +Div<T>,
    +BitAnd<T>,
    +PartialEq<T>,
    +Copy<T>,
    +Drop<T>
> of Exponentiation<T> {
    fn pow(self: T, mut exponent: T) -> T {
        let zero = Zero::zero();
        if self.is_zero() {
            return zero;
        }
        let one = One::one();
        let mut result = one;
        let mut base = self;
        let two = one + one;

        loop {
            if exponent & one == one {
                result = result * base;
            }

            exponent = exponent / two;
            if exponent == zero {
                break result;
            }

            base = base * base;
        }
    }
}

pub trait WrappingExponentiation<T> {
    /// Raise a number to a power modulo MAX<T> (max value of type T).
    /// Instead of explicitly providing a modulo, we use overflowing functions
    /// from the core library, which wrap around when overflowing.
    ///
    /// # Arguments
    ///
    /// * `self` - The base number
    /// * `exponent` - The exponent to raise the base to
    ///
    /// # Returns
    ///
    /// The result of base raised to the power of exp modulo MAX<T>.
    fn wrapping_pow(self: T, exponent: T) -> T;

    /// Performs exponentiation by repeatedly multiplying the base number with itself.
    ///
    /// This function uses a simple loop to perform exponentiation. It continues to multiply
    /// the base number (`self`) with itself, for the number of times specified by `exponent`.
    /// The method uses a wrapping strategy to handle overflow, which means if the result
    /// overflows the type `T`, then higher bits are discarded and the result is wrapped.
    ///
    /// # Arguments
    ///
    /// * `self` - The base number of type `T`.
    /// * `exponent` - The exponent to which the base number is raised, also of type `T`.
    ///
    /// # Returns
    ///
    /// The result of raising `self` to the power of `exponent`, of type `T`.
    /// The result is wrapped in case of overflow.
    fn wrapping_spow(self: T, exponent: T) -> T;

    /// Performs exponentiation using the binary exponentiation method.
    ///
    /// This function calculates the power of a number using binary exponentiation, which is
    /// an optimized method for exponentiation that reduces the number of multiplications.
    /// It works by repeatedly squaring the base and reducing the exponent by half, using
    /// a wrapping strategy to handle overflow. This means if intermediate or final results
    /// overflow the type `T`, then the higher bits are discarded and the result is wrapped.
    ///
    /// # Arguments
    ///
    /// * `self` - The base number of type `T`.
    /// * `exponent` - The exponent to which the base number is raised, also of type `T`.
    ///
    /// # Returns
    ///
    /// The result of raising `self` to the power of `exponent`, of type `T`.
    /// The result is wrapped in case of overflow.
    fn wrapping_fpow(self: T, exponent: T) -> T;
}


pub impl WrappingExponentiationImpl<
    T,
    +OverflowingMul<T>,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Mul<T>,
    +Div<T>,
    +Rem<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialEq<T>,
    +PartialOrd<T>,
    +core::ops::SubAssign<T, T>
> of WrappingExponentiation<T> {
    fn wrapping_pow(self: T, exponent: T) -> T {
        if exponent == Zero::zero() {
            return One::one();
        }

        if self == Zero::zero() {
            return Zero::zero();
        }

        let one = One::<T>::one();
        let ten = one + one + one + one + one + one + one + one + one + one;

        if exponent > ten {
            self.wrapping_fpow(exponent)
        } else {
            self.wrapping_spow(exponent)
        }
    }

    fn wrapping_spow(self: T, exponent: T) -> T {
        let mut exponent = exponent;
        let mut base = self;
        let mut result = One::one();

        while exponent != Zero::zero() {
            let (new_result, _) = result.overflowing_mul(base);
            result = new_result;
            exponent -= One::one();
        };
        result
    }

    fn wrapping_fpow(self: T, exponent: T) -> T {
        let mut result = One::one();
        let mut base = self;
        let mut exponent = exponent;
        let two = One::<T>::one() + One::<T>::one();

        loop {
            if exponent % two != Zero::zero() {
                let (new_result, _) = result.overflowing_mul(base);
                result = new_result;
            }

            exponent = exponent / two;
            if exponent == Zero::zero() {
                break result;
            }

            let (new_base, _) = base.overflowing_mul(base);
            base = new_base;
        }
    }
}

// === BitShift ===

pub trait Bitshift<T> {
    /// Shift a number left by a given number of bits.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` left by `shift` bits
    ///
    /// # Panics
    ///
    /// Panics if the shift is greater than 255.
    /// Panics if the result overflows the type T.
    fn shl(self: T, shift: T) -> T;

    /// Shift a number right by a given number of bits.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` right by `shift` bits
    ///
    /// # Panics
    ///
    /// Panics if the shift is greater than 255.
    fn shr(self: T, shift: T) -> T;
}

impl BitshiftImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Mul<T>,
    +Exponentiation<T>,
    +Copy<T>,
    +Drop<T>,
    +PartialOrd<T>,
    +BitSize<T>,
    +TryInto<usize, T>,
> of Bitshift<T> {
    fn shl(self: T, shift: T) -> T {
        // if we shift by more than nb_bits of T, the result is 0
        // we early return to save gas and prevent unexpected behavior
        if shift > BitSize::<T>::bits().try_into().unwrap() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self * two.pow(shift)
    }

    fn shr(self: T, shift: T) -> T {
        // early return to save gas if shift > nb_bits of T
        if shift > BitSize::<T>::bits().try_into().unwrap() - One::one() {
            panic_with_felt252('mul Overflow');
        }
        let two = One::one() + One::one();
        self / two.pow(shift)
    }
}

pub trait WrappingBitshift<T> {
    /// Shift a number left by a given number of bits.
    /// If the shift is greater than 255, the result is 0.
    /// The bits moved after the 256th one are discarded, the new bits are set to 0.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` left by `shift` bits, wrapped if necessary
    fn wrapping_shl(self: T, shift: T) -> T;

    /// Shift a number right by a given number of bits.
    /// If the shift is greater than 255, the result is 0.
    ///
    /// # Arguments
    ///
    /// * `self` - The number to shift
    /// * `shift` - The number of bits to shift by
    ///
    /// # Returns
    ///
    /// The result of shifting `self` right by `shift` bits, or 0 if shift > 255
    fn wrapping_shr(self: T, shift: T) -> T;
}

pub impl WrappingBitshiftImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Div<T>,
    +Exponentiation<T>,
    +PartialOrd<T>,
    +Drop<T>,
    +Copy<T>,
    +OverflowingMul<T>,
    +WrappingExponentiation<T>,
    +BitSize<T>,
    +TryInto<usize, T>,
> of WrappingBitshift<T> {
    fn wrapping_shl(self: T, shift: T) -> T {
        let two = One::<T>::one() + One::<T>::one();
        let (result, _) = self.overflowing_mul(two.wrapping_pow(shift));
        result
    }

    fn wrapping_shr(self: T, shift: T) -> T {
        let two = One::<T>::one() + One::<T>::one();

        if shift > BitSize::<T>::bits().try_into().unwrap() - One::one() {
            return Zero::zero();
        }
        self / two.pow(shift)
    }
}

// === Standalone functions ===

/// Adds two 256-bit unsigned integers, returning a 512-bit unsigned integer result.
///
/// limb3 will always be 0, because the maximum sum of two 256-bit numbers is at most
/// 2**257 - 2 which fits in 257 bits.
///
/// # Arguments
///
/// * `a` - First 256-bit unsigned integer
/// * `b` - Second 256-bit unsigned integer
///
/// # Returns
///
/// A 512-bit unsigned integer representing the sum of `a` and `b`
pub fn u256_wide_add(a: u256, b: u256) -> u512 {
    let (sum, overflow) = a.overflowing_add(b);

    let limb0 = sum.low;
    let limb1 = sum.high;

    let limb2 = if overflow {
        1
    } else {
        0
    };

    let limb3 = 0;

    u512 { limb0, limb1, limb2, limb3 }
}

#[cfg(test)]
mod tests {
    use core::integer::{u512};
    use core::num::traits::{OverflowingMul, WrappingMul, SaturatingAdd, Bounded};
    use crate::math::{
        Exponentiation, WrappingExponentiation, u256_wide_add, Bitshift, WrappingBitshift,
    };
    use super::OverflowingAdd;

    #[test]
    fn test_wrapping_pow() {
        assert(5_u256.wrapping_pow(10) == 9765625, '5^10 should be 9765625');
        assert(
            5_u256
                .wrapping_pow(
                    90
                ) == 807793566946316088741610050849573099185363389551639556884765625,
            '5^90 failed'
        );
        assert(2_u256.wrapping_pow(256) == 0, 'should wrap to 0');
        assert(123456_u256.wrapping_pow(0) == 1, 'n^0 should be 1');
        assert(0_u256.wrapping_pow(123456) == 0, '0^n should be 0');
    }

    #[test]
    fn test_pow() {
        assert(5_u256.pow(10) == 9765625, '5^10 should be 9765625');
        assert(5_u256.pow(45) == 28421709430404007434844970703125, '5^45 failed');
        assert(123456_u256.pow(0) == 1, 'n^0 should be 1');
        assert(0_u256.pow(123456) == 0, '0^n should be 0');
    }

    #[test]
    fn test_wrapping_fast_pow() {
        let exp = 3_u256.wrapping_fpow(10);
        assert(
            3_u256
                .wrapping_fpow(
                    exp
                ) == 6701808933569337837891967767170127839253608180143676463326689955522159283811,
            '3^(3^10) failed'
        );
    }

    #[test]
    fn test_wrapping_fast_pow_0() {
        assert(3_u256.wrapping_fpow(0) == 1, '3^(0) should be 1');
    }

    #[test]
    fn test_wrapping_fast_base_0() {
        assert(0_u256.wrapping_fpow(42) == 0, '0^(42) should be 0');
    }

    #[test]
    fn test_wrapping_fast_base_0_pow_0() {
        assert(0_u256.wrapping_fpow(0) == 1, '0^(0) should be 1');
    }

    #[test]
    #[should_panic(expected: ('u256_mul Overflow',))]
    fn test_pow_should_overflow() {
        2_u256.pow(256);
    }


    #[test]
    fn test_wide_add_basic() {
        let a = 1000;
        let b = 500;

        let (_, overflow) = a.overflowing_add(b);

        let expected = u512 { limb0: 1500, limb1: 0, limb2: 0, limb3: 0, };

        let result = u256_wide_add(a, b);

        assert(!overflow, 'shouldnt overflow');
        assert(result == expected, 'wrong result');
    }

    #[test]
    fn test_wide_add_overflow() {
        let a = Bounded::<u256>::MAX;
        let b = 1;

        let (_, overflow) = a.overflowing_add(b);

        let expected = u512 { limb0: 0, limb1: 0, limb2: 1, limb3: 0, };

        let result = u256_wide_add(a, b);

        assert(overflow, 'should overflow');
        assert(result == expected, 'wrong result');
    }

    #[test]
    fn test_wide_add_max_values() {
        let a = Bounded::<u256>::MAX;
        let b = Bounded::<u256>::MAX;

        let expected = u512 {
            limb0: 0xfffffffffffffffffffffffffffffffe,
            limb1: 0xffffffffffffffffffffffffffffffff,
            limb2: 1,
            limb3: 0,
        };

        let result = u256_wide_add(a, b);

        assert(result == expected, 'wrong result');
    }

    #[test]
    fn test_shl() {
        // Given
        let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 3 * 8;

        // When
        let result = a.shl(shift);

        // Then
        let expected = 0x91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f000000_u256;
        assert(result == expected, 'wrong result');
    }


    #[test]
    #[should_panic(expected: ('mul Overflow',))]
    fn test_shl_256_bits_overflow() {
        // Given
        let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 32 * 8;

        // When & Then 2.pow(256) overflows u256
        a.shl(shift);
    }

    #[test]
    #[should_panic(expected: ('u256_mul Overflow',))]
    fn test_shl_overflow() {
        // Given
        let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 4 * 8;

        // When & Then a << 32 overflows u256
        a.shl(shift);
    }

    #[test]
    fn test_wrapping_shl_overflow() {
        // Given
        let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498faab3fe_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 12 * 8;

        // When
        let result = a.wrapping_shl(shift);

        // Then
        // The bits moved after the 256th one are discarded, the new bits are set to 0.
        let expected = 0xf24201bac4e64f70ca2b9d9491e82a498faab3fe000000000000000000000000_u256;
        assert(result == expected, 'wrong result');
    }


    #[test]
    fn test_wrapping_shl() {
        // Given
        let a = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 3 * 8;

        // When
        let result = a.wrapping_shl(shift);

        // Then
        let expected = 0x91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aab3f000000_u256;
        assert(result == expected, 'wrong result');
    }

    #[test]
    fn test_shr() {
        // Given
        let a = 0x0091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 1 * 8;

        // When
        let result = a.shr(shift);

        // Then
        let expected = 0x000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade626_u256;
        assert(result == expected, 'wrong result');
    }

    #[test]
    #[should_panic(expected: ('mul Overflow',))]
    fn test_shr_256_bits_overflow() {
        let a = 0xab91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
        let shift = 32 * 8;

        // When & Then 2.pow(256) overflows u256
        a.shr(shift);
    }


    #[test]
    fn test_wrapping_shr() {
        // Given
        let a = 0x0091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 2 * 8;

        // When
        let result = a.wrapping_shr(shift);

        // Then
        let expected = 0x00000091b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6_u256;
        assert(result == expected, 'wrong result');
    }


    #[test]
    fn test_wrapping_shr_to_zero() {
        // Given
        let a = 0xab91b2efa2bfd58aee61f24201bac4e64f70ca2b9d9491e82a498f2aade6263a_u256;
        // 1-byte shift is an 8-bit shift
        let shift = 32 * 8;

        // When
        let result = a.wrapping_shr(shift);

        // Then
        let expected = 0_u256;
        assert(result == expected, 'wrong result');
    }

    #[test]
    fn test_u8_overflowing_mul_not_overflow_case() {
        let result = 5_u8.overflowing_mul(10);
        assert_eq!(result, (50, false));
    }

    #[test]
    fn test_u8_overflowing_mul_overflow_case() {
        let result = Bounded::<u8>::MAX.overflowing_mul(Bounded::MAX);
        assert_eq!(result, (1, true));
    }

    #[test]
    fn test_u8_wrapping_mul_not_overflow_case() {
        let result = 5_u8.wrapping_mul(10);
        assert_eq!(result, 50);
    }

    #[test]
    fn test_u8_wrapping_mul_overflow_case() {
        let result = Bounded::<u8>::MAX.wrapping_mul(Bounded::MAX);
        assert_eq!(result, 1);
    }

    #[test]
    fn test_u32_overflowing_mul_not_overflow_case() {
        let result = 5_u32.overflowing_mul(10);
        assert_eq!(result, (50, false));
    }

    #[test]
    fn test_u32_overflowing_mul_overflow_case() {
        let result = Bounded::<u32>::MAX.overflowing_mul(Bounded::MAX);
        assert_eq!(result, (1, true));
    }

    #[test]
    fn test_u32_wrapping_mul_not_overflow_case() {
        let result = 5_u32.wrapping_mul(10);
        assert_eq!(result, 50);
    }

    #[test]
    fn test_u32_wrapping_mul_overflow_case() {
        let result = Bounded::<u32>::MAX.wrapping_mul(Bounded::MAX);
        assert_eq!(result, 1);
    }


    #[test]
    fn test_u64_overflowing_mul_not_overflow_case() {
        let result = 5_u64.overflowing_mul(10);
        assert_eq!(result, (50, false));
    }

    #[test]
    fn test_u64_overflowing_mul_overflow_case() {
        let result = Bounded::<u64>::MAX.overflowing_mul(Bounded::MAX);
        assert_eq!(result, (1, true));
    }

    #[test]
    fn test_u64_wrapping_mul_not_overflow_case() {
        let result = 5_u64.wrapping_mul(10);
        assert_eq!(result, 50);
    }

    #[test]
    fn test_u64_wrapping_mul_overflow_case() {
        let result = Bounded::<u64>::MAX.wrapping_mul(Bounded::MAX);
        assert_eq!(result, 1);
    }


    #[test]
    fn test_u128_overflowing_mul_not_overflow_case() {
        let result = 5_u128.overflowing_mul(10);
        assert_eq!(result, (50, false));
    }

    #[test]
    fn test_u128_overflowing_mul_overflow_case() {
        let result = Bounded::<u128>::MAX.overflowing_mul(Bounded::MAX);
        assert_eq!(result, (1, true));
    }

    #[test]
    fn test_u128_wrapping_mul_not_overflow_case() {
        let result = 5_u128.wrapping_mul(10);
        assert_eq!(result, 50);
    }

    #[test]
    fn test_u128_wrapping_mul_overflow_case() {
        let result = Bounded::<u128>::MAX.wrapping_mul(Bounded::MAX);
        assert_eq!(result, 1);
    }

    #[test]
    fn test_u256_overflowing_mul_not_overflow_case() {
        let result = 5_u256.overflowing_mul(10);
        assert_eq!(result, (50, false));
    }

    #[test]
    fn test_u256_overflowing_mul_overflow_case() {
        let result = Bounded::<u256>::MAX.overflowing_mul(Bounded::MAX);
        assert_eq!(result, (1, true));
    }

    #[test]
    fn test_u256_wrapping_mul_not_overflow_case() {
        let result = 5_u256.wrapping_mul(10);
        assert_eq!(result, 50);
    }

    #[test]
    fn test_u256_wrapping_mul_overflow_case() {
        let result = Bounded::<u256>::MAX.wrapping_mul(Bounded::MAX);
        assert_eq!(result, 1);
    }

    #[test]
    fn test_saturating_add() {
        let max = Bounded::<u8>::MAX;

        assert_eq!(max.saturating_add(1), Bounded::<u8>::MAX);
        assert_eq!((max - 2).saturating_add(1), max - 1);
    }
}
