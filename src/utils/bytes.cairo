from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem, split_int, split_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset
from starkware.cairo.common.registers import get_label_location

from utils.array import reverse, pad_end

func felt_to_ascii{range_check_ptr}(dst: felt*, n: felt) -> felt {
    alloc_locals;
    let (local ascii: felt*) = alloc();

    tempvar range_check_ptr = range_check_ptr;
    tempvar n = n;
    tempvar ascii_len = 0;

    body:
    let ascii = cast([fp], felt*);
    let range_check_ptr = [ap - 3];
    let n = [ap - 2];
    let ascii_len = [ap - 1];

    let (n, chunk) = unsigned_div_rem(n, 10);
    assert [ascii + ascii_len] = chunk + '0';

    tempvar range_check_ptr = range_check_ptr;
    tempvar n = n;
    tempvar ascii_len = ascii_len + 1;

    jmp body if n != 0;

    let range_check_ptr = [ap - 3];
    let ascii_len = [ap - 1];
    let ascii = cast([fp], felt*);

    reverse(dst, ascii_len, ascii);

    return ascii_len;
}

// @notice Split a felt into an array of bytes little endian
// @dev Use a hint from split_int
func felt_to_bytes_little(dst: felt*, value: felt) -> felt {
    alloc_locals;

    tempvar value = value;
    tempvar bytes_len = 0;

    body:
    let value = [ap - 2];
    let bytes_len = [ap - 1];
    let bytes = cast([fp - 4], felt*);
    let output = bytes + bytes_len;
    let base = 2 ** 8;
    let bound = base;

    %{
        memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
        assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
    %}
    let byte = [output];
    let value = (value - byte) / base;

    tempvar value = value;
    tempvar bytes_len = bytes_len + 1;

    jmp body if value != 0;

    let value = [ap - 2];
    let bytes_len = [ap - 1];
    assert value = 0;

    return bytes_len;
}

// @notice Split a felt into an array of bytes
func felt_to_bytes(dst: felt*, value: felt) -> felt {
    alloc_locals;
    let (local bytes: felt*) = alloc();
    let bytes_len = felt_to_bytes_little(bytes, value);
    reverse(dst, bytes_len, bytes);

    return bytes_len;
}

// @notice Split a felt into an array of bytes of size i
// @dev The array is padded with zeros if the felt is smaller than i bytes
func felt_to_bytes_i{range_check_ptr}(dst: felt*, value: felt, bytes_len: felt) -> felt {
    alloc_locals;
    let (local bytes: felt*) = alloc();
    let actual_len = felt_to_bytes_little(bytes, value);
    pad_end(actual_len, bytes, bytes_len);
    reverse(dst, bytes_len, bytes);

    return bytes_len;
}

// @notice Split a felt into an array of 20 bytes, big endian
// @dev Truncate the high 12 bytes
func felt_to_bytes20{range_check_ptr}(dst: felt*, value: felt) {
    alloc_locals;
    let (bytes20: felt*) = alloc();
    let (high, low) = split_felt(value);
    let (_, high) = unsigned_div_rem(high, 2 ** 32);
    split_int(low, 16, 256, 256, bytes20);
    split_int(high, 4, 256, 256, bytes20 + 16);
    reverse(dst, 20, bytes20);
    return ();
}

func felt_to_bytes32{range_check_ptr}(dst: felt*, value: felt) {
    alloc_locals;
    let (bytes32: felt*) = alloc();
    let (high, low) = split_felt(value);
    split_int(low, 16, 256, 256, bytes32);
    split_int(high, 16, 256, 256, bytes32 + 16);
    reverse(dst, 32, bytes32);
    return ();
}

func uint256_to_bytes_little{range_check_ptr}(dst: felt*, n: Uint256) -> felt {
    alloc_locals;
    let (local highest_byte, safe_high) = unsigned_div_rem(n.high, 2 ** 120);
    local range_check_ptr = range_check_ptr;

    let value = n.low + safe_high * 2 ** 128;
    let len = felt_to_bytes_little(dst, value);
    if (highest_byte != 0) {
        memset(dst + len, 0, 31 - len);
        assert [dst + 31] = highest_byte;
        tempvar bytes_len = 32;
    } else {
        tempvar bytes_len = len;
    }

    return bytes_len;
}

func uint256_to_bytes{range_check_ptr}(dst: felt*, n: Uint256) -> felt {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = uint256_to_bytes_little(bytes, n);
    reverse(dst, bytes_len, bytes);
    return bytes_len;
}

func uint256_to_bytes32{range_check_ptr}(dst: felt*, n: Uint256) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = uint256_to_bytes_little(bytes, n);
    memset(dst, 0, 32 - bytes_len);
    reverse(dst + 32 - bytes_len, bytes_len, bytes);
    return ();
}

// @notice Converts an array of bytes to an array of bytes8, little endian
// @dev The individual bytes are packed into 8-byte words, little endian.
//     The last word is returned separately, along with the number of used bytes
//     as it may be incomplete.
// @param dst The destination array.
// @param bytes_len The number of bytes in the input array.
// @param bytes The input array.
// @return The number of bytes written to the destination array.
// @return The last word.
// @return The number of bytes used in the last word
func bytes_to_bytes8_little_endian{range_check_ptr}(dst: felt*, bytes_len: felt, bytes: felt*) -> (
    felt, felt, felt
) {
    alloc_locals;

    if (bytes_len == 0) {
        return (0, 0, 0);
    }

    let (local pow256) = get_label_location(pow256_table);
    let (full_u64_word_count, local last_input_num_bytes) = unsigned_div_rem(bytes_len, 8);
    local range_check_ptr = range_check_ptr;

    tempvar dst_index = 0;
    tempvar bytes_index = bytes_len - 1;
    tempvar bytes8 = 0;
    tempvar bytes8_index = 7;

    body:
    let dst_index = [ap - 4];
    let bytes_index = [ap - 3];
    let bytes8 = [ap - 2];
    let bytes8_index = [ap - 1];

    let bytes_len = [fp - 4];
    let bytes = cast([fp - 3], felt*);
    let pow256 = cast([fp], felt*);
    let current_byte = bytes[bytes_len - 1 - bytes_index];
    let current_pow = pow256[bytes8_index];

    tempvar bytes8 = bytes8 + current_byte * current_pow;

    jmp next if bytes_index != 0;
    jmp end_word_not_full if bytes8_index != 0;

    let last_input_num_bytes = [fp + 1];
    assert [dst + dst_index] = bytes8;
    let range_check_ptr = [fp + 2];
    return (dst_index + 1, 0, 0);

    next:
    jmp regular if bytes8_index != 0;

    assert [dst + dst_index] = bytes8;

    tempvar dst_index = dst_index + 1;
    tempvar bytes_index = bytes_index - 1;
    tempvar bytes8 = 0;
    tempvar bytes8_index = 7;
    static_assert dst_index == [ap - 4];
    static_assert bytes_index == [ap - 3];
    static_assert bytes8 == [ap - 2];
    static_assert bytes8_index == [ap - 1];
    jmp body;

    regular:
    tempvar dst_index = dst_index;
    tempvar bytes_index = bytes_index - 1;
    tempvar bytes8 = bytes8;
    tempvar bytes8_index = bytes8_index - 1;
    static_assert dst_index == [ap - 4];
    static_assert bytes_index == [ap - 3];
    static_assert bytes8 == [ap - 2];
    static_assert bytes8_index == [ap - 1];
    jmp body;

    end_word_not_full:
    tempvar dst_index = dst_index;
    tempvar bytes8 = bytes8;

    let range_check_ptr = [fp + 2];
    return (dst_index, bytes8, last_input_num_bytes);

    pow256_table:
    dw 256 ** 7;
    dw 256 ** 6;
    dw 256 ** 5;
    dw 256 ** 4;
    dw 256 ** 3;
    dw 256 ** 2;
    dw 256 ** 1;
    dw 256 ** 0;
}
