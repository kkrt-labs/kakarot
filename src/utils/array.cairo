from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset
from starkware.cairo.common.math_cmp import is_not_zero, is_le

func reverse(arr_len: felt, arr: felt*) -> felt* {
    alloc_locals;

    if (arr_len == 0) {
        return arr;
    }

    let (local rev: felt*) = alloc();
    tempvar i = arr_len;

    body:
    let arr_len = [fp - 4];
    let arr = cast([fp - 3], felt*);
    let rev = cast([fp], felt*);
    let i = [ap - 1];

    assert [rev + i - 1] = [arr + arr_len - i];
    tempvar i = i - 1;

    jmp body if i != 0;

    let rev = cast([fp], felt*);
    return rev;
}

func count_not_zero(arr_len: felt, arr: felt*) -> felt {
    if (arr_len == 0) {
        return 0;
    }

    tempvar len = arr_len;
    tempvar count = 0;
    tempvar arr = arr;

    body:
    let len = [ap - 3];
    let count = [ap - 2];
    let arr = cast([ap - 1], felt*);
    let not_zero = is_not_zero([arr]);

    tempvar len = len - 1;
    tempvar count = count + not_zero;
    tempvar arr = arr + 1;

    jmp body if len != 0;

    let count = [ap - 2];

    return count;
}
