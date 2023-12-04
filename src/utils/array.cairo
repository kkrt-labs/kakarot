from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset
from starkware.cairo.common.math_cmp import is_not_zero, is_nn
from starkware.cairo.common.bool import FALSE

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

// @notice Fills slice with a slice of data.
// @dev If the slice is out of bounds, the function pads with zeros.
func slice{range_check_ptr}(slice: felt*, data_len: felt, data: felt*, offset: felt, size: felt) {
    alloc_locals;

    if (size == 0) {
        return ();
    }

    let overlap = is_nn(data_len - offset);
    if (overlap == FALSE) {
        memset(dst=slice, value=0, n=size);
        return ();
    }

    let max_len = (data_len - offset);
    let is_within_bound = is_nn(max_len - size);
    if (is_within_bound != FALSE) {
        memcpy(dst=slice, src=data + offset, len=size);
        return ();
    }

    memcpy(dst=slice, src=data + offset, len=max_len);
    memset(dst=slice + max_len, value=0, n=size - max_len);
    return ();
}
