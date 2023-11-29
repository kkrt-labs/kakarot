from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem, split_int, assert_nn
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

from utils.array import reverse

func felt_to_ascii{range_check_ptr}(n: felt) -> (ascii_len: felt, ascii: felt*) {
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

    let ascii = reverse(ascii_len, ascii);

    return (ascii_len, ascii);
}
