// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from utils.array import reverse, count_not_zero, slice

@external
func test__reverse{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arr_len: felt, arr: felt*
) -> (rev_len: felt, rev: felt*) {
    let rev = reverse(arr_len, arr);
    return (rev_len=arr_len, rev=rev);
}

@external
func test__count_not_zero{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arr_len: felt, arr: felt*
) -> (count: felt) {
    let count = count_not_zero(arr_len, arr);
    return (count=count);
}

@external
func test__slice{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    arr_len: felt, arr: felt*, offset: felt, size: felt
) -> (slice_len: felt, slice: felt*) {
    alloc_locals;
    let (sliced: felt*) = alloc();
    slice(sliced, arr_len, arr, offset, size);
    return (slice_len=size, slice=sliced);
}
