from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
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

func bytes_to_bytes8_little_endian(dst: felt*, bytes_len: felt, bytes: felt*) -> felt {
    alloc_locals;

    if (bytes_len == 0) {
        return (0);
    }

    let (local pow256) = get_label_location(pow256_table);

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

    assert [dst + dst_index] = bytes8;
    return (dst_index + 1);

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
