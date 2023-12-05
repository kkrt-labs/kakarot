from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem, split_int, assert_nn, split_felt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset
from starkware.cairo.common.registers import get_label_location

from utils.array import reverse

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

// @notice Split a felt into an array of bytes
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
// @dev Use a hint from split_int
func felt_to_bytes(dst: felt*, value: felt) -> felt {
    alloc_locals;
    let (local bytes: felt*) = alloc();
    let bytes_len = felt_to_bytes_little(bytes, value);
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

func bytes_to_bytes8_little_endian(dst: felt*, bytes_len: felt, bytes: felt*) -> felt {
    alloc_locals;

    let (local pow256) = get_label_location(pow256_table);

    tempvar dst_index = 0;
    tempvar i = bytes_len - 1;
    tempvar bytes8 = 0;
    tempvar remaining_bytes = 8;

    body:
    let dst_index = [ap - 4];
    let i = [ap - 3];
    let bytes8 = [ap - 2];
    let remaining_bytes = [ap - 1];

    let bytes_len = [fp - 4];
    let bytes = cast([fp - 3], felt*);
    let pow256 = cast([fp], felt*);
    let current_byte = bytes[bytes_len - 1 - i];
    let current_pow = pow256[remaining_bytes - 1];

    tempvar bytes8 = bytes8 + current_byte * current_pow;

    jmp next if i != 0;

    assert [dst + dst_index] = bytes8;
    return (dst_index + 1);

    next:
    jmp regular if remaining_bytes != 0;

    assert [dst + dst_index] = bytes8;

    tempvar dst_index = dst_index + 1;
    tempvar i = i - 1;
    tempvar bytes8 = 0;
    tempvar remaining_bytes = 8;
    static_assert dst_index == [ap - 4];
    static_assert i == [ap - 3];
    static_assert bytes8 == [ap - 2];
    static_assert remaining_bytes == [ap - 1];
    jmp body;

    regular:
    tempvar dst_index = dst_index;
    tempvar i = i - 1;
    tempvar bytes8 = bytes8;
    tempvar remaining_bytes = remaining_bytes - 1;
    static_assert dst_index == [ap - 4];
    static_assert i == [ap - 3];
    static_assert bytes8 == [ap - 2];
    static_assert remaining_bytes == [ap - 1];
    jmp body;

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
