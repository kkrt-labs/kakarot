use core::cmp::min;
use core::keccak::{cairo_keccak};
use core::num::traits::{Zero, One, Bounded, BitSize, SaturatingAdd};
use core::traits::{BitAnd};
use crate::constants::{POW_2, POW_256_1, POW_256_REV};
use crate::math::{Bitshift};
use crate::traits::integer::{BytesUsedTrait, ByteSize, U256Trait};

#[generate_trait]
pub impl U8SpanExImpl of U8SpanExTrait {
    /// Computes the keccak256 hash of a bytes message
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// # Returns
    /// * The keccak256 hash as a u256
    fn compute_keccak256_hash(self: Span<u8>) -> u256 {
        let (mut keccak_input, last_input_word, last_input_num_bytes) = self.to_u64_words();
        let hash = cairo_keccak(ref keccak_input, :last_input_word, :last_input_num_bytes)
            .reverse_endianness();

        hash
    }

    /// Transforms a Span<u8> into an Array of u64 full words, a pending u64 word and its length in
    /// bytes
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// # Returns
    /// * A tuple containing:
    ///   - An Array<u64> of full words
    ///   - A u64 representing the last (potentially partial) word
    ///   - A usize representing the number of bytes in the last word
    fn to_u64_words(self: Span<u8>) -> (Array<u64>, u64, usize) {
        let nonzero_8: NonZero<u32> = 8_u32.try_into().unwrap();
        let (full_u64_word_count, last_input_num_bytes) = DivRem::div_rem(self.len(), nonzero_8);

        let mut u64_words: Array<u64> = Default::default();
        let mut byte_counter: u8 = 0;
        let mut pending_word: u64 = 0;
        let mut u64_word_counter: usize = 0;

        while u64_word_counter != full_u64_word_count {
            if byte_counter == 8 {
                u64_words.append(pending_word);
                byte_counter = 0;
                pending_word = 0;
                u64_word_counter += 1;
            }
            pending_word += match self.get(u64_word_counter * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = (*byte.unbox()).into();
                    // Accumulate pending_word in a little endian manner
                    byte.shl(8_u32 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        };

        // Fill the last input word
        let mut last_input_word: u64 = 0;

        // We enter a second loop for clarity.
        // O(2n) should be okay
        // We might want to regroup every computation into a single loop with appropriate `if`
        // branching For optimisation
        for byte_counter in 0
            ..last_input_num_bytes {
                last_input_word += match self.get(full_u64_word_count * 8 + byte_counter.into()) {
                    Option::Some(byte) => {
                        let byte: u64 = (*byte.unbox()).into();
                        byte.shl(8_u32 * byte_counter.into())
                    },
                    Option::None => { break; },
                };
            };

        (u64_words, last_input_word, last_input_num_bytes)
    }

    /// Returns right padded slice of the span, starting from index offset
    /// If offset is greater than the span length, returns an empty span
    /// # Examples
    ///
    /// ```
    ///   let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
    ///   let expected = [0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
    ///   let result = span.slice_right_padded(4, 10);
    ///   assert_eq!(result, expected);
    /// ```
    /// # Arguments
    /// * `offset` - The offset to start the slice from
    /// * `len` - The length of the slice
    ///
    /// # Returns
    /// * A span of length `len` starting from `offset` right padded with 0s if `offset` is greater
    /// than the span length, returns an empty span of length `len` if offset is grearter than the
    /// span length
    fn slice_right_padded(self: Span<u8>, offset: usize, len: usize) -> Span<u8> {
        let start = if offset <= self.len() {
            offset
        } else {
            self.len()
        };

        let end = min(start.saturating_add(len), self.len());

        let slice = self.slice(start, end - start);
        // Save appending to span for this case as it is more efficient to just return the slice
        if slice.len() == len {
            return slice;
        }

        // Copy the span
        let mut arr = array![];
        arr.append_span(slice);

        while arr.len() != len {
            arr.append(0);
        };

        arr.span()
    }

    /// Clones and pads the given span with 0s to the right to the given length
    /// If data is more than the given length, it is truncated from the right side
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// * `len` - The desired length of the padded span
    /// # Returns
    /// * A Span<u8> of length `len` right padded with 0s if the span length is less than `len`,
    ///   or truncated from the right if the span length is greater than `len`
    /// # Examples
    /// ```
    /// let span = array![1, 2, 3].span();
    /// let padded = span.pad_right_with_zeroes(5);
    /// assert_eq!(padded, array![1, 2, 3, 0, 0].span());
    /// ```
    fn pad_right_with_zeroes(self: Span<u8>, len: usize) -> Span<u8> {
        if self.len() >= len {
            return self.slice(0, len);
        }

        // Create a new array with the original data
        let mut arr = array![];
        for i in self {
            arr.append(*i);
        };

        // Pad with zeroes
        while arr.len() != len {
            arr.append(0);
        };

        arr.span()
    }


    /// Clones and pads the given span with 0s to the left to the given length
    /// If data is more than the given length, it is truncated from the right side
    /// # Arguments
    /// * `self` - The input bytes as a Span<u8>
    /// * `len` - The desired length of the padded span
    /// # Returns
    /// * A Span<u8> of length `len` left padded with 0s if the span length is less than `len`,
    ///   or truncated from the right if the span length is greater than `len`
    /// # Examples
    /// ```
    /// let span = array![1, 2, 3].span();
    /// let padded = span.pad_left_with_zeroes(5);
    /// assert_eq!(padded, array![0, 0, 1, 2, 3].span());
    /// ```
    fn pad_left_with_zeroes(self: Span<u8>, len: usize) -> Span<u8> {
        if self.len() >= len {
            return self.slice(0, len);
        }

        // left pad with 0
        let mut arr = array![];
        while arr.len() != (len - self.len()) {
            arr.append(0);
        };

        // append the data
        for item in self {
            arr.append(*item);
        };

        arr.span()
    }
}

pub trait ToBytes<T> {
    /// Unpacks a type T into a span of big endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in big endian.
    fn to_be_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of big endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in big endian padded to the byte size of T.
    fn to_be_bytes_padded(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytes representation of the value in little endian.
    fn to_le_bytes(self: T) -> Span<u8>;
    /// Unpacks a type T into a span of little endian bytes, padded to the byte size of T
    ///
    /// # Arguments
    /// * `self` a value of type T.
    ///
    /// # Returns
    /// * The bytesrepresentation of the value in little endian padded to the byte size of T.
    fn to_le_bytes_padded(self: T) -> Span<u8>;
}

pub impl ToBytesImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +BitAnd<T>,
    +Bitshift<T>,
    +BitSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +core::ops::AddAssign<T, T>,
    +PartialEq<T>
> of ToBytes<T> {
    fn to_be_bytes(self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();

        // 0xFF
        let mask = Bounded::<u8>::MAX.into();

        let mut bytes: Array<u8> = Default::default();
        for i in 0
            ..bytes_used {
                let val = Bitshift::<T>::shr(self, 8_u32 * (bytes_used.into() - i.into() - 1));
                bytes.append((val & mask).try_into().unwrap());
            };

        bytes.span()
    }

    fn to_be_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_be_bytes().pad_left_with_zeroes(padding)
    }

    fn to_le_bytes(mut self: T) -> Span<u8> {
        let bytes_used = self.bytes_used();

        // 0xFF
        let mask = Bounded::<u8>::MAX.into();

        let mut bytes: Array<u8> = Default::default();

        for i in 0
            ..bytes_used {
                let val = self.shr(8_u32 * i.into());
                bytes.append((val & mask).try_into().unwrap());
            };

        bytes.span()
    }

    fn to_le_bytes_padded(mut self: T) -> Span<u8> {
        let padding = (BitSize::<T>::bits() / 8);
        self.to_le_bytes().slice_right_padded(0, padding)
    }
}

pub trait FromBytes<T> {
    /// Parses a span of big endian bytes into a type T
    ///
    /// # Arguments
    /// * `self` a span of big endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in big endian, Option::None if the span is
    /// not the byte size of T.
    fn from_be_bytes(self: Span<u8>) -> Option<T>;

    /// Parses a span of big endian bytes into a type T, allowing for partial input
    ///
    /// # Arguments
    /// * `self` a span of big endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in big endian, Option::None if the span is
    /// longer than the byte size of T.
    fn from_be_bytes_partial(self: Span<u8>) -> Option<T>;


    /// Parses a span of little endian bytes into a type T
    ///
    /// # Arguments
    /// * `self` a span of little endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in little endian, Option::None if the span is
    /// not the byte size of T.
    fn from_le_bytes(self: Span<u8>) -> Option<T>;

    /// Parses a span of little endian bytes into a type T, allowing for partial input
    ///
    /// # Arguments
    /// * `self` a span of little endian bytes.
    ///
    /// # Returns
    /// * The Option::(value) represented by the bytes in little endian, Option::None if the span is
    /// longer than the byte size of T.
    fn from_le_bytes_partial(self: Span<u8>) -> Option<T>;
}

pub impl FromBytesImpl<
    T,
    +Zero<T>,
    +One<T>,
    +Add<T>,
    +Sub<T>,
    +Mul<T>,
    +BitAnd<T>,
    +Bitshift<T>,
    +ByteSize<T>,
    +BytesUsedTrait<T>,
    +Into<u8, T>,
    +Into<u16, T>,
    +TryInto<T, u8>,
    +Copy<T>,
    +Drop<T>,
    +core::ops::AddAssign<T, T>,
    +PartialEq<T>
> of FromBytes<T> {
    fn from_be_bytes(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();

        if self.len() != byte_size {
            return Option::None;
        }

        let mut result: T = Zero::zero();
        for byte in self {
            let tmp = result * 256_u16.into();
            result = tmp + (*byte).into();
        };
        Option::Some(result)
    }

    fn from_be_bytes_partial(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();

        if self.len() > byte_size {
            return Option::None;
        }

        let mut result: T = Zero::zero();
        for byte in self {
            let tmp = result * 256_u16.into();
            result = tmp + (*byte).into();
        };

        Option::Some(result)
    }

    fn from_le_bytes(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();

        if self.len() != byte_size {
            return Option::None;
        }

        let mut result: T = Zero::zero();
        let mut i = self.len();
        while i != 0 {
            i -= 1;
            let tmp = result * 256_u16.into();
            result = tmp + (*self[i]).into();
        };
        Option::Some(result)
    }

    fn from_le_bytes_partial(self: Span<u8>) -> Option<T> {
        let byte_size = ByteSize::<T>::byte_size();

        if self.len() > byte_size {
            return Option::None;
        }

        let mut result: T = Zero::zero();
        let mut i = self.len();
        while i != 0 {
            i -= 1;
            let tmp = result * 256_u16.into();
            result = tmp + (*self[i]).into();
        };
        Option::Some(result)
    }
}


#[generate_trait]
pub impl ByteArrayExt of ByteArrayExTrait {
    /// Appends a span of bytes to the ByteArray
    /// # Arguments
    /// * `self` - The ByteArray to append to
    /// * `bytes` - The span of bytes to append
    fn append_span_bytes(ref self: ByteArray, mut bytes: Span<u8>) {
        for val in bytes {
            self.append_byte(*val);
        };
    }

    /// Creates a ByteArray from a span of bytes
    /// # Arguments
    /// * `bytes` - The span of bytes to convert
    /// # Returns
    /// * A new ByteArray containing the input bytes
    fn from_bytes(mut bytes: Span<u8>) -> ByteArray {
        let mut arr: ByteArray = Default::default();
        let (nb_full_words, pending_word_len) = DivRem::div_rem(
            bytes.len(), 31_u32.try_into().unwrap()
        );
        for _ in 0
            ..nb_full_words {
                let mut word: felt252 = 0;
                for _ in 0
                    ..31_u8 {
                        word = word * POW_256_1.into() + (*bytes.pop_front().unwrap()).into();
                    };
                arr.append_word(word.try_into().unwrap(), 31);
            };

        if pending_word_len == 0 {
            return arr;
        };

        let mut pending_word: felt252 = 0;

        for _ in 0
            ..pending_word_len {
                pending_word = pending_word * POW_256_1.into()
                    + (*bytes.pop_front().unwrap()).into();
            };
        arr.append_word(pending_word.try_into().unwrap(), pending_word_len);
        arr
    }

    /// Checks if the ByteArray is empty
    /// # Arguments
    /// * `self` - The ByteArray to check
    /// # Returns
    /// * true if the ByteArray is empty, false otherwise
    fn is_empty(self: @ByteArray) -> bool {
        self.len() == 0
    }

    /// Converts the ByteArray into a span of bytes
    /// # Arguments
    /// * `self` - The ByteArray to convert
    /// # Returns
    /// * A Span<u8> containing the bytes from the ByteArray
    fn into_bytes(self: ByteArray) -> Span<u8> {
        let mut output: Array<u8> = Default::default();
        for i in 0..self.len() {
            output.append(self[i]);
        };
        output.span()
    }


    /// Transforms a ByteArray into an Array of u64 full words, a pending u64 word and its length in
    /// bytes
    /// # Arguments
    /// * `self` - The ByteArray to transform
    /// # Returns
    /// * A tuple containing:
    ///   - An Array<u64> of full words
    ///   - A u64 representing the last (potentially partial) word
    ///   - A usize representing the number of bytes in the last word
    fn to_u64_words(self: ByteArray) -> (Array<u64>, u64, usize) {
        // We pass it by value because we want to take ownership, but we snap it
        // because `at` takes a snap and if this snap is automatically done by
        // the compiler in the loop, it won't compile
        let self = @self;
        let nonzero_8: NonZero<u32> = 8_u32.try_into().unwrap();
        let (full_u64_word_count, last_input_num_bytes) = DivRem::div_rem(self.len(), nonzero_8);

        let mut u64_words: Array<u64> = Default::default();
        let mut byte_counter: u8 = 0;
        let mut pending_word: u64 = 0;
        let mut u64_word_counter: usize = 0;

        while u64_word_counter != full_u64_word_count {
            if byte_counter == 8 {
                u64_words.append(pending_word);
                byte_counter = 0;
                pending_word = 0;
                u64_word_counter += 1;
            }
            pending_word += match self.at(u64_word_counter * 8 + byte_counter.into()) {
                Option::Some(byte) => {
                    let byte: u64 = byte.into();
                    // Accumulate pending_word in a little endian manner
                    byte.shl(8_u32 * byte_counter.into())
                },
                Option::None => { break; },
            };
            byte_counter += 1;
        };

        // Fill the last input word
        let mut last_input_word: u64 = 0;

        // We enter a second loop for clarity.
        // O(2n) should be okay
        // We might want to regroup every computation into a single loop with appropriate `if`
        // branching For optimisation

        for byte_counter in 0
            ..last_input_num_bytes {
                last_input_word += match self.at(full_u64_word_count * 8 + byte_counter.into()) {
                    Option::Some(byte) => {
                        let byte: u64 = byte.into();
                        byte.shl(8_u32 * byte_counter.into())
                    },
                    Option::None => { break; },
                };
            };

        (u64_words, last_input_word, last_input_num_bytes)
    }
}


#[cfg(test)]
mod tests {
    mod bytearray_test {
        use super::super::{ByteArrayExTrait};
        #[test]
        fn test_pack_bytes_ge_bytes31() {
            let mut arr = array![
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0A,
                0x0B,
                0x0C,
                0x0D,
                0x0E,
                0x0F,
                0x10,
                0x11,
                0x12,
                0x13,
                0x14,
                0x15,
                0x16,
                0x17,
                0x18,
                0x19,
                0x1A,
                0x1B,
                0x1C,
                0x1D,
                0x1E,
                0x1F,
                0x20,
                0x21 // 33 elements
            ];

            let res = ByteArrayExTrait::from_bytes(arr.span());

            // Ensure that the result is complete and keeps the same order
            for i in 0..arr.len() {
                assert(*arr[i] == res[i], 'byte mismatch');
            };
        }

        #[test]
        fn test_bytearray_append_span_bytes() {
            let bytes = array![0x01, 0x02, 0x03, 0x04];
            let mut byte_arr: ByteArray = Default::default();
            byte_arr.append_byte(0xFF);
            byte_arr.append_byte(0xAA);
            byte_arr.append_span_bytes(bytes.span());
            assert_eq!(byte_arr.len(), 6);
            assert_eq!(byte_arr[0], 0xFF);
            assert_eq!(byte_arr[1], 0xAA);
            assert_eq!(byte_arr[2], 0x01);
            assert_eq!(byte_arr[3], 0x02);
            assert_eq!(byte_arr[4], 0x03);
            assert_eq!(byte_arr[5], 0x04);
        }

        #[test]
        fn test_byte_array_into_bytes() {
            let input = array![
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0A,
                0x0B,
                0x0C,
                0x0D,
                0x0E,
                0x0F,
                0x10,
                0x11,
                0x12,
                0x13,
                0x14,
                0x15,
                0x16,
                0x17,
                0x18,
                0x19,
                0x1A,
                0x1B,
                0x1C,
                0x1D,
                0x1E,
                0x1F,
                0x20,
                0x21 // 33 elements
            ];
            let byte_array = ByteArrayExTrait::from_bytes(input.span());
            let res = byte_array.into_bytes();

            // Ensure that the elements are correct
            assert(res == input.span(), 'bytes mismatch');
        }

        #[test]
        fn test_pack_bytes_le_bytes31() {
            let mut arr = array![0x11, 0x22, 0x33, 0x44];
            let res = ByteArrayExTrait::from_bytes(arr.span());

            // Ensure that the result is complete and keeps the same order
            for i in 0..arr.len() {
                assert(*arr[i] == res[i], 'byte mismatch');
            };
        }


        #[test]
        fn test_bytearray_to_64_words_partial() {
            let input = ByteArrayExTrait::from_bytes([0x01, 0x02, 0x03, 0x04, 0x05, 0x06].span());
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();
            assert(pending_word == 6618611909121, 'wrong pending word');
            assert(pending_word_len == 6, 'wrong pending word length');
            assert(u64_words.len() == 0, 'wrong u64 words length');
        }

        #[test]
        fn test_bytearray_to_64_words_full() {
            let input = ByteArrayExTrait::from_bytes(
                [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08].span()
            );
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();

            assert(pending_word == 0, 'wrong pending word');
            assert(pending_word_len == 0, 'wrong pending word length');
            assert(u64_words.len() == 1, 'wrong u64 words length');
            assert(*u64_words[0] == 578437695752307201, 'wrong u64 words length');
        }
    }


    mod span_u8_test {
        use super::super::{U8SpanExTrait, ToBytes};

        #[test]
        fn test_span_u8_to_64_words_partial() {
            let mut input: Span<u8> = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06].span();
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();
            assert(pending_word == 6618611909121, 'wrong pending word');
            assert(pending_word_len == 6, 'wrong pending word length');
            assert(u64_words.len() == 0, 'wrong u64 words length');
        }

        #[test]
        fn test_span_u8_to_64_words_full() {
            let mut input: Span<u8> = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08].span();
            let (u64_words, pending_word, pending_word_len) = input.to_u64_words();

            assert(pending_word == 0, 'wrong pending word');
            assert(pending_word_len == 0, 'wrong pending word length');
            assert(u64_words.len() == 1, 'wrong u64 words length');
            assert(*u64_words[0] == 578437695752307201, 'wrong u64 words length');
        }


        #[test]
        fn test_compute_msg_hash() {
            let msg = 0xabcdef_u32.to_be_bytes();
            let expected_hash = 0x800d501693feda2226878e1ec7869eef8919dbc5bd10c2bcd031b94d73492860;
            let hash = msg.compute_keccak256_hash();

            assert_eq!(hash, expected_hash);
        }

        #[test]
        fn test_right_padded_span_offset_0() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(0, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_right_padded_span_offset_4() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(4, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_right_padded_span_offset_greater_than_span_len() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.slice_right_padded(6, 10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_10() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x0, 0x0, 0x0, 0x0, 0x0, 0x01, 0x02, 0x03, 0x04, 0x05].span();
            let result = span.pad_left_with_zeroes(10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_equal_than_data_len() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let expected = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let result = span.pad_left_with_zeroes(10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_left_with_zeroes_len_equal_than_smaller_len() {
            let span = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8, 0x9].span();
            let expected = [0x0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x6, 0x7, 0x8].span();
            let result = span.pad_left_with_zeroes(9);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_right_with_zeroes_len_10() {
            let span = [0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x01, 0x02, 0x03, 0x04, 0x05, 0x0, 0x0, 0x0, 0x0, 0x0].span();
            let result = span.pad_right_with_zeroes(10);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_right_with_zeroes_truncate() {
            let span = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a].span();
            let expected = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09].span();
            let result = span.pad_right_with_zeroes(9);

            assert_eq!(result, expected);
        }

        #[test]
        fn test_pad_right_with_zeroes_same_length() {
            let span = [0x01, 0x02, 0x03, 0x04, 0x05].span();
            let expected = [0x01, 0x02, 0x03, 0x04, 0x05].span();
            let result = span.pad_right_with_zeroes(5);

            assert_eq!(result, expected);
        }
    }
}
