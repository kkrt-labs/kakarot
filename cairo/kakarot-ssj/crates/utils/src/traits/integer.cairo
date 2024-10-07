use core::integer::{u128_byte_reverse};
use core::num::traits::{Zero, One, Bounded, BitSize};
use crate::helpers::{u128_split};
use crate::math::{Bitshift};

#[generate_trait]
pub impl U64Impl of U64Trait {
    /// Returns the number of trailing zeroes in the bit representation of `self`.
    /// # Arguments
    /// * `self` a `u64` value.
    /// # Returns
    /// * The number of trailing zeroes in the bit representation of `self`.
    fn count_trailing_zeroes(self: u64) -> u8 {
        let mut count = 0;

        if self == 0 {
            return 64; // If n is 0, all 64 bits are zeros
        };

        let mut mask = 1;

        while (self & mask) == 0 {
            count += 1;
            mask *= 2;
        };

        count
    }
}


#[generate_trait]
pub impl U128Impl of U128Trait {
    /// Returns the Least significant 64 bits of a u128
    fn as_u64(self: u128) -> u64 {
        let (_, bottom_word) = u128_split(self);
        bottom_word
    }
}

#[generate_trait]
pub impl U256Impl of U256Trait {
    /// Splits an u256 into 4 little endian u64.
    /// Returns ((high_high, high_low),(low_high, low_low))
    fn split_into_u64_le(self: u256) -> ((u64, u64), (u64, u64)) {
        let low_le = u128_byte_reverse(self.low);
        let high_le = u128_byte_reverse(self.high);
        (u128_split(high_le), u128_split(low_le))
    }

    /// Reverse the endianness of an u256
    fn reverse_endianness(self: u256) -> u256 {
        let new_low = u128_byte_reverse(self.high);
        let new_high = u128_byte_reverse(self.low);
        u256 { low: new_low, high: new_high }
    }
}

pub trait BytesUsedTrait<T> {
    /// Returns the number of bytes used to represent a `T` value.
    /// # Arguments
    /// * `self` - The value to check.
    /// # Returns
    /// The number of bytes used to represent the value.
    fn bytes_used(self: T) -> u8;
}

pub impl U8BytesUsedTraitImpl of BytesUsedTrait<u8> {
    fn bytes_used(self: u8) -> u8 {
        if self == 0 {
            return 0;
        }

        return 1;
    }
}

pub impl USizeBytesUsedTraitImpl of BytesUsedTrait<usize> {
    fn bytes_used(self: usize) -> u8 {
        if self < 0x10000 { // 256^2
            if self < 0x100 { // 256^1
                if self == 0 {
                    return 0;
                } else {
                    return 1;
                };
            }
            return 2;
        } else {
            if self < 0x1000000 { // 256^3
                return 3;
            }
            return 4;
        }
    }
}

pub impl U64BytesUsedTraitImpl of BytesUsedTrait<u64> {
    fn bytes_used(self: u64) -> u8 {
        if self <= Bounded::<u32>::MAX.into() { // 256^4
            return BytesUsedTrait::<u32>::bytes_used(self.try_into().unwrap());
        } else {
            if self < 0x1000000000000 { // 256^6
                if self < 0x10000000000 {
                    if self < 0x100000000 {
                        return 4;
                    }
                    return 5;
                }
                return 6;
            } else {
                if self < 0x100000000000000 { // 256^7
                    return 7;
                } else {
                    return 8;
                }
            }
        }
    }
}

pub impl U128BytesTraitUsedImpl of BytesUsedTrait<u128> {
    fn bytes_used(self: u128) -> u8 {
        let (u64high, u64low) = u128_split(self);
        if u64high == 0 {
            return BytesUsedTrait::<u64>::bytes_used(u64low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u64>::bytes_used(u64high.try_into().unwrap()) + 8;
        }
    }
}

pub impl U256BytesUsedTraitImpl of BytesUsedTrait<u256> {
    fn bytes_used(self: u256) -> u8 {
        if self.high == 0 {
            return BytesUsedTrait::<u128>::bytes_used(self.low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u128>::bytes_used(self.high.try_into().unwrap()) + 16;
        }
    }
}

pub trait ByteSize<T> {
    fn byte_size() -> usize;
}

pub impl ByteSizeImpl<T, +BitSize<T>> of ByteSize<T> {
    fn byte_size() -> usize {
        BitSize::<T>::bits() / 8
    }
}

pub trait BitsUsed<T> {
    /// Returns the number of bits required to represent `self`, ignoring leading zeros.
    /// # Arguments
    /// `self` - The value to check.
    /// # Returns
    /// The number of bits used to represent the value, ignoring leading zeros.
    fn bits_used(self: T) -> u32;

    /// Returns the number of leading zeroes in the bit representation of `self`.
    /// # Arguments
    /// `self` - The value to check.
    /// # Returns
    /// The number of leading zeroes in the bit representation of `self`.
    fn count_leading_zeroes(self: T) -> u32;
}

pub impl BitsUsedImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +Bitshift<T>,
    +BitSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +PartialEq<T>
> of BitsUsed<T> {
    fn bits_used(self: T) -> u32 {
        if self == Zero::zero() {
            return 0;
        }

        let bytes_used = self.bytes_used();
        let last_byte = self.shr(8_u32 * (bytes_used.into() - One::one()));

        // safe unwrap since we know at most 8 bits are used
        let bits_used: u8 = bits_used_internal::bits_used_in_byte(last_byte.try_into().unwrap());

        bits_used.into() + 8 * (bytes_used - 1).into()
    }

    fn count_leading_zeroes(self: T) -> u32 {
        BitSize::<T>::bits() - self.bits_used()
    }
}

pub(crate) mod bits_used_internal {
    /// Returns the number of bits used to represent the value in binary representation
    /// # Arguments
    /// * `self` - The value to compute the number of bits used
    /// # Returns
    /// * The number of bits used to represent the value in binary representation
    pub(crate) fn bits_used_in_byte(self: u8) -> u8 {
        if self < 0b100000 {
            if self < 0b1000 {
                if self < 0b100 {
                    if self < 0b10 {
                        if self == 0 {
                            return 0;
                        } else {
                            return 1;
                        };
                    }
                    return 2;
                }

                return 3;
            }

            if self < 0b10000 {
                return 4;
            }

            return 5;
        } else {
            if self < 0b10000000 {
                if self < 0b1000000 {
                    return 6;
                }
                return 7;
            }
            return 8;
        }
    }
}

#[cfg(test)]
mod tests {
    mod u8_test {
        use crate::math::Bitshift;
        use crate::traits::bytes::{ToBytes, FromBytes};
        use super::super::BitsUsed;

        #[test]
        fn test_bits_used() {
            assert_eq!(0x00_u8.bits_used(), 0);
            let mut value: u8 = 0xff;
            let mut i = 8;
            loop {
                assert_eq!(value.bits_used(), i);
                if i == 0 {
                    break;
                };
                value = value.shr(1);

                i -= 1;
            };
        }

        #[test]
        fn test_u8_to_le_bytes() {
            let input: u8 = 0xf4;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0xf4].span());
        }

        #[test]
        fn test_u8_to_le_bytes_padded() {
            let input: u8 = 0xf4;
            let res: Span<u8> = input.to_le_bytes_padded();

            assert_eq!(res, [0xf4].span());
        }
    }

    mod u32_test {
        use crate::math::Bitshift;
        use crate::traits::bytes::{ToBytes, FromBytes};
        use super::super::{BytesUsedTrait};

        #[test]
        fn test_u32_from_be_bytes() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62];
            let res: Option<u32> = input.span().from_be_bytes();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf4321562);
        }

        #[test]
        fn test_u32_from_be_bytes_too_big_should_return_none() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62, 0x01];
            let res: Option<u32> = input.span().from_be_bytes();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_be_bytes_too_small_should_return_none() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15];
            let res: Option<u32> = input.span().from_be_bytes();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_be_bytes_partial() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62];
            let res: Option<u32> = input.span().from_be_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf4321562);
        }

        #[test]
        fn test_u32_from_be_bytes_partial_smaller_input() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15];
            let res: Option<u32> = input.span().from_be_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf43215);
        }

        #[test]
        fn test_u32_from_be_bytes_partial_single_byte() {
            let input: Array<u8> = array![0xf4];
            let res: Option<u32> = input.span().from_be_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf4);
        }

        #[test]
        fn test_u32_from_be_bytes_partial_empty_input() {
            let input: Array<u8> = array![];
            let res: Option<u32> = input.span().from_be_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0);
        }

        #[test]
        fn test_u32_from_be_bytes_partial_too_big_input() {
            let input: Array<u8> = array![0xf4, 0x32, 0x15, 0x62, 0x01];
            let res: Option<u32> = input.span().from_be_bytes_partial();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_le_bytes() {
            let input: Array<u8> = array![0x62, 0x15, 0x32, 0xf4];
            let res: Option<u32> = input.span().from_le_bytes();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf4321562);
        }

        #[test]
        fn test_u32_from_le_bytes_too_big() {
            let input: Array<u8> = array![0x62, 0x15, 0x32, 0xf4, 0x01];
            let res: Option<u32> = input.span().from_le_bytes();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_le_bytes_too_small() {
            let input: Array<u8> = array![0x62, 0x15, 0x32];
            let res: Option<u32> = input.span().from_le_bytes();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_le_bytes_zero() {
            let input: Array<u8> = array![0x00, 0x00, 0x00, 0x00];
            let res: Option<u32> = input.span().from_le_bytes();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0);
        }

        #[test]
        fn test_u32_from_le_bytes_max() {
            let input: Array<u8> = array![0xff, 0xff, 0xff, 0xff];
            let res: Option<u32> = input.span().from_le_bytes();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xffffffff);
        }

        #[test]
        fn test_u32_from_le_bytes_partial() {
            let input: Array<u8> = array![0x62, 0x15, 0x32];
            let res: Option<u32> = input.span().from_le_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0x321562);
        }

        #[test]
        fn test_u32_from_le_bytes_partial_full() {
            let input: Array<u8> = array![0x62, 0x15, 0x32, 0xf4];
            let res: Option<u32> = input.span().from_le_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xf4321562);
        }

        #[test]
        fn test_u32_from_le_bytes_partial_too_big() {
            let input: Array<u8> = array![0x62, 0x15, 0x32, 0xf4, 0x01];
            let res: Option<u32> = input.span().from_le_bytes_partial();

            assert!(res.is_none());
        }

        #[test]
        fn test_u32_from_le_bytes_partial_empty() {
            let input: Array<u8> = array![];
            let res: Option<u32> = input.span().from_le_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0);
        }

        #[test]
        fn test_u32_from_le_bytes_partial_single_byte() {
            let input: Array<u8> = array![0xff];
            let res: Option<u32> = input.span().from_le_bytes_partial();

            assert!(res.is_some());
            assert_eq!(res.unwrap(), 0xff);
        }

        #[test]
        fn test_u32_to_bytes_full() {
            let input: u32 = 0xf4321562;
            let res: Span<u8> = input.to_be_bytes();

            assert_eq!(res, [0xf4, 0x32, 0x15, 0x62].span());
        }

        #[test]
        fn test_u32_to_bytes_partial() {
            let input: u32 = 0xf43215;
            let res: Span<u8> = input.to_be_bytes();

            assert_eq!(res.len(), 3);
            assert_eq!(*res[0], 0xf4);
            assert_eq!(*res[1], 0x32);
            assert_eq!(*res[2], 0x15);
        }


        #[test]
        fn test_u32_to_bytes_leading_zeros() {
            let input: u32 = 0x001234;
            let res: Span<u8> = input.to_be_bytes();

            assert_eq!(res.len(), 2);
            assert_eq!(*res[0], 0x12);
            assert_eq!(*res[1], 0x34);
        }

        #[test]
        fn test_u32_to_be_bytes_padded() {
            let input: u32 = 7;
            let result = input.to_be_bytes_padded();
            let expected = [0x0, 0x0, 0x0, 7].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u32_to_le_bytes_full() {
            let input: u32 = 0xf4321562;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0x62, 0x15, 0x32, 0xf4].span());
        }

        #[test]
        fn test_u32_to_le_bytes_partial() {
            let input: u32 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res.len(), 3);
            assert_eq!(*res[0], 0x15);
            assert_eq!(*res[1], 0x32);
            assert_eq!(*res[2], 0xf4);
        }

        #[test]
        fn test_u32_to_le_bytes_leading_zeros() {
            let input: u32 = 0x00f432;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res.len(), 2);
            assert_eq!(*res[0], 0x32);
            assert_eq!(*res[1], 0xf4);
        }

        #[test]
        fn test_u32_to_le_bytes_padded() {
            let input: u32 = 7;
            let result = input.to_le_bytes_padded();
            let expected = [7, 0x0, 0x0, 0x0].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u32_bytes_used() {
            assert_eq!(0x00_u32.bytes_used(), 0);
            let mut value: u32 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 4 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u32_bytes_used_leading_zeroes() {
            let len: u32 = 0x001234;
            let bytes_count = len.bytes_used();

            assert_eq!(bytes_count, 2);
        }
    }

    mod u64_test {
        use crate::math::Bitshift;
        use crate::traits::bytes::{ToBytes};
        use super::super::{BitsUsed, BytesUsedTrait, U64Trait};


        #[test]
        fn test_u64_bytes_used() {
            assert_eq!(0x00_u64.bytes_used(), 0);
            let mut value: u64 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 8 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u64_to_be_bytes_padded() {
            let input: u64 = 7;
            let result = input.to_be_bytes_padded();
            let expected = [0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 7].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_trailing_zeroes() {
            /// bit len is 3, and trailing zeroes are 2
            let input: u64 = 4;
            let result = input.count_trailing_zeroes();
            let expected = 2;

            assert_eq!(result, expected);
        }


        #[test]
        fn test_u64_leading_zeroes() {
            /// bit len is 3, and leading zeroes are 64 - 3 = 61
            let input: u64 = 7;
            let result = input.count_leading_zeroes();
            let expected = 61;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_bits_used() {
            let input: u64 = 7;
            let result = input.bits_used();
            let expected = 3;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u64_to_le_bytes_full() {
            let input: u64 = 0xf432156278901234;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0x34, 0x12, 0x90, 0x78, 0x62, 0x15, 0x32, 0xf4].span());
        }

        #[test]
        fn test_u64_to_le_bytes_partial() {
            let input: u64 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0x15, 0x32, 0xf4].span());
        }

        #[test]
        fn test_u64_to_le_bytes_padded() {
            let input: u64 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes_padded();

            assert_eq!(res, [0x15, 0x32, 0xf4, 0x00, 0x00, 0x00, 0x00, 0x00].span());
        }
    }

    mod u128_test {
        use core::num::traits::Bounded;
        use crate::math::Bitshift;
        use crate::traits::bytes::{ToBytes};
        use super::super::{BitsUsed, BytesUsedTrait};

        #[test]
        fn test_u128_bytes_used() {
            assert_eq!(0x00_u128.bytes_used(), 0);
            let mut value: u128 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 16 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u128_to_bytes_full() {
            let input: u128 = Bounded::MAX;
            let result: Span<u8> = input.to_be_bytes();
            let expected = [
                255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
            ].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u128_to_bytes_partial() {
            let input: u128 = 0xf43215;
            let result: Span<u8> = input.to_be_bytes();
            let expected = [0xf4, 0x32, 0x15].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u128_to_bytes_padded() {
            let input: u128 = 0xf43215;
            let result: Span<u8> = input.to_be_bytes_padded();
            let expected = [
                0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xf4, 0x32, 0x15
            ].span();

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u128_to_le_bytes_full() {
            let input: u128 = 0xf432156278901234deadbeefcafebabe;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(
                res,
                [
                    0xbe,
                    0xba,
                    0xfe,
                    0xca,
                    0xef,
                    0xbe,
                    0xad,
                    0xde,
                    0x34,
                    0x12,
                    0x90,
                    0x78,
                    0x62,
                    0x15,
                    0x32,
                    0xf4
                ].span()
            );
        }

        #[test]
        fn test_u128_to_le_bytes_partial() {
            let input: u128 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0x15, 0x32, 0xf4].span());
        }

        #[test]
        fn test_u128_to_le_bytes_padded() {
            let input: u128 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes_padded();

            assert_eq!(
                res,
                [
                    0x15,
                    0x32,
                    0xf4,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00
                ].span()
            );
        }
    }

    mod u256_test {
        use crate::math::Bitshift;
        use crate::traits::bytes::{ToBytes};
        use crate::traits::integer::{U256Trait};
        use super::super::{BitsUsed, BytesUsedTrait};

        #[test]
        fn test_reverse_bytes_u256() {
            let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
            let res = value.reverse_endianness();
            assert(
                res == 0x0000450000DEFA0000200400000000ADDE00000077000000E5000000FFFFFFFA,
                'reverse mismatch'
            );
        }

        #[test]
        fn test_split_u256_into_u64_little() {
            let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
            let ((high_h, low_h), (high_l, low_l)) = value.split_into_u64_le();
            assert_eq!(high_h, 0xDE00000077000000);
            assert_eq!(low_h, 0xE5000000FFFFFFFA);
            assert_eq!(high_l, 0x0000450000DEFA00);
            assert_eq!(low_l, 0x00200400000000AD);
        }

        #[test]
        fn test_u256_bytes_used() {
            assert_eq!(0x00_u256.bytes_used(), 0);
            let mut value: u256 = 0xff;
            let mut i = 1;
            loop {
                assert_eq!(value.bytes_used(), i);
                if i == 32 {
                    break;
                };
                i += 1;
                value = value.shl(8);
            };
        }

        #[test]
        fn test_u256_leading_zeroes() {
            /// bit len is 3, and leading zeroes are 256 - 3 = 253
            let input: u256 = 7;
            let result = input.count_leading_zeroes();
            let expected = 253;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u256_bits_used() {
            let input: u256 = 7;
            let result = input.bits_used();
            let expected = 3;

            assert_eq!(result, expected);
        }

        #[test]
        fn test_u256_to_be_bytes_full() {
            let input: u256 = 0xf432156278901234deadbeefcafebabe0123456789abcdef0fedcba987654321;
            let res: Span<u8> = input.to_be_bytes();

            assert_eq!(
                res,
                [
                    0xf4,
                    0x32,
                    0x15,
                    0x62,
                    0x78,
                    0x90,
                    0x12,
                    0x34,
                    0xde,
                    0xad,
                    0xbe,
                    0xef,
                    0xca,
                    0xfe,
                    0xba,
                    0xbe,
                    0x01,
                    0x23,
                    0x45,
                    0x67,
                    0x89,
                    0xab,
                    0xcd,
                    0xef,
                    0x0f,
                    0xed,
                    0xcb,
                    0xa9,
                    0x87,
                    0x65,
                    0x43,
                    0x21
                ].span()
            );
        }

        #[test]
        fn test_u256_to_be_bytes_partial() {
            let input: u256 = 0xf43215;
            let res: Span<u8> = input.to_be_bytes();

            assert_eq!(res, [0xf4, 0x32, 0x15].span());
        }

        #[test]
        fn test_u256_to_be_bytes_padded() {
            let input: u256 = 0xf43215;
            let res: Span<u8> = input.to_be_bytes_padded();

            assert_eq!(
                res,
                [
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0xf4,
                    0x32,
                    0x15
                ].span()
            );
        }

        #[test]
        fn test_u256_to_le_bytes_full() {
            let input: u256 = 0xf432156278901234deadbeefcafebabe0123456789abcdef0fedcba987654321;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(
                res,
                [
                    0x21,
                    0x43,
                    0x65,
                    0x87,
                    0xa9,
                    0xcb,
                    0xed,
                    0x0f,
                    0xef,
                    0xcd,
                    0xab,
                    0x89,
                    0x67,
                    0x45,
                    0x23,
                    0x01,
                    0xbe,
                    0xba,
                    0xfe,
                    0xca,
                    0xef,
                    0xbe,
                    0xad,
                    0xde,
                    0x34,
                    0x12,
                    0x90,
                    0x78,
                    0x62,
                    0x15,
                    0x32,
                    0xf4
                ].span()
            );
        }

        #[test]
        fn test_u256_to_le_bytes_partial() {
            let input: u256 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes();

            assert_eq!(res, [0x15, 0x32, 0xf4].span());
        }

        #[test]
        fn test_u256_to_le_bytes_padded() {
            let input: u256 = 0xf43215;
            let res: Span<u8> = input.to_le_bytes_padded();

            assert_eq!(
                res,
                [
                    0x15,
                    0x32,
                    0xf4,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00
                ].span()
            );
        }
    }
}
