use core::num::traits::Zero;

/// Pack an array of bytes into 31-byte words and a final word.
/// The bytes are packed in big-endian order.
///
/// # Arguments
/// * `input` - An array of bytes to pack.
///
/// # Returns
/// An array of felt252 values containing the packed bytes. The last word might not be full.
pub fn pack_bytes(input: Span<u8>) -> Array<felt252> {
    let mut result: Array<felt252> = Default::default();
    let mut current_word: u256 = 0;
    let mut byte_count: usize = 0;

    for byte in input {
        current_word = (current_word * 256) + (*byte).into();
        byte_count += 1;

        if byte_count == 31 {
            result.append(current_word.try_into().unwrap());
            current_word = 0;
            byte_count = 0;
        }
    };

    // Append the last word if there are any remaining bytes
    if byte_count != 0 {
        result.append(current_word.try_into().unwrap());
    }

    result
}

/// Load packed bytes from an array of bytes packed in 31-byte words and a final word.
///
/// # Arguments
///
/// * `input` - An array of 31-bytes words and a final word.
/// * `bytes_len` - The total number of bytes to unpack.
///
/// # Returns
///
/// An `Array<u8>` containing the unpacked bytes in big-endian order.
///
/// # Performance considerations
///
/// This function uses head-recursive helper functions (`unpack_chunk`) for unpacking individual
/// felt252 values. Head recursion is used here instead of loops because the Array type in Cairo is
/// append-only. This approach allows us to append the bytes in the correct order (big-endian)
/// without needing to reverse the array afterwards. This leads to more efficient memory usage and
/// performance.
pub fn load_packed_bytes(input: Span<felt252>, bytes_len: u32) -> Array<u8> {
    if input.is_empty() {
        return Default::default();
    }
    let (chunk_counts, remainder) = DivRem::div_rem(bytes_len, 31);
    let mut res: Array<u8> = Default::default();

    for i in 0
        ..chunk_counts {
            let mut value: u256 = (*input[i]).into();
            unpack_chunk(value, 31, ref res);
        };

    if remainder.is_zero() {
        return res;
    }
    unpack_chunk((*input[input.len() - 1]).into(), remainder, ref res);
    res
}


/// Unpacks only a specified number of bytes from the value.  Uses head recursion to append bytes in
/// big-endian order.
///
/// # Arguments
///
/// * `value` - The u256 value to unpack.
/// * `remaining_bytes` - The number of bytes to unpack from the value.
/// * `output` - The array to append the unpacked bytes to.
fn unpack_chunk(value: u256, remaining_bytes: u32, ref output: Array<u8>) {
    if remaining_bytes == 0 {
        return;
    }
    let (q, r) = DivRem::div_rem(value, 256);
    unpack_chunk(q, remaining_bytes - 1, ref output);
    output.append(r.try_into().unwrap());
}

#[cfg(test)]
mod tests {
    use super::{load_packed_bytes, pack_bytes};

    #[test]
    fn test_should_load_empty_array() {
        let res = load_packed_bytes([].span(), 0);

        assert_eq!(res.span(), [].span());
    }

    #[test]
    fn test_should_load_zeroes() {
        let input = [0x00, 0x00];
        let res = load_packed_bytes(input.span(), 35);

        assert_eq!(res.span(), [0x00; 35].span());
    }

    #[test]
    fn test_should_load_single_31bytes_felt() {
        let input = [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff];
        let res = load_packed_bytes(input.span(), 31);

        assert_eq!(res.span(), [0xff; 31].span());
    }

    #[test]
    fn test_should_load_with_non_full_last_felt() {
        let input = [0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0xffff];
        let res = load_packed_bytes(input.span(), 33);

        assert_eq!(res.span(), [0xff; 33].span());
    }

    #[test]
    fn test_should_load_multiple_words() {
        let input = [
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            0xffff
        ];
        let res = load_packed_bytes(input.span(), 64);

        assert_eq!(res.span(), [0xff; 64].span());
    }

    #[test]
    fn test_should_load_mixed_byte_values_big_endian() {
        let input = [0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e, 0x1f2021];
        let res = load_packed_bytes(input.span(), 34);
        assert_eq!(
            res.span(),
            [
                0x00,
                0x01,
                0x02,
                0x03,
                0x04,
                0x05,
                0x06,
                0x07,
                0x08,
                0x09,
                0x0a,
                0x0b,
                0x0c,
                0x0d,
                0x0e,
                0x0f,
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
                0x1a,
                0x1b,
                0x1c,
                0x1d,
                0x1e,
                0x1f,
                0x20,
                0x21
            ].span()
        );
    }

    #[test]
    fn test_should_pack_empty_array() {
        let res = pack_bytes([].span());

        assert_eq!(res, array![]);
    }

    #[test]
    fn test_should_pack_single_31bytes_felt() {
        let input = [0xff; 31];
        let res = pack_bytes(input.span());

        assert_eq!(res, array![0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff]);
    }

    #[test]
    fn test_should_pack_with_non_full_last_felt() {
        let mut input = [0xff; 33];
        let res = pack_bytes(input.span());

        assert_eq!(
            res, array![0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff, 0xffff]
        );
    }

    #[test]
    fn test_should_pack_multiple_words() {
        let input = [0xff; 64];
        let res = pack_bytes(input.span());

        assert_eq!(
            res,
            array![
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
                0xffff
            ]
        );
    }

    #[test]
    fn test_should_pack_mixed_byte_values_big_endian() {
        let input = [
            0x00,
            0x01,
            0x02,
            0x03,
            0x04,
            0x05,
            0x06,
            0x07,
            0x08,
            0x09,
            0x0a,
            0x0b,
            0x0c,
            0x0d,
            0x0e,
            0x0f,
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
            0x1a,
            0x1b,
            0x1c,
            0x1d,
            0x1e,
            0x1f,
            0x20,
            0x21
        ];
        let res = pack_bytes(input.span());
        assert_eq!(
            res, array![0x000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e, 0x1f2021]
        );
    }

    #[test]
    fn test_pack_and_unpack_roundtrip() {
        let original = [
            0x00,
            0x01,
            0x02,
            0x03,
            0x04,
            0x05,
            0x06,
            0x07,
            0x08,
            0x09,
            0x0a,
            0x0b,
            0x0c,
            0x0d,
            0x0e,
            0x0f,
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
            0x1a,
            0x1b,
            0x1c,
            0x1d,
            0x1e,
            0x1f,
            0x20,
            0x21
        ].span();
        let packed = pack_bytes(original);
        let unpacked = load_packed_bytes(packed.span(), original.len().try_into().unwrap());
        assert_eq!(original, unpacked.span());
    }
}
