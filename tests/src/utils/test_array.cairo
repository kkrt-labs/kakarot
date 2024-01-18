%builtins range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from utils.array import reverse, count_not_zero, slice, contains

func test__reverse(output_ptr: felt*) {
    alloc_locals;
    tempvar arr_len: felt;
    let (arr) = alloc();
    %{
        ids.arr_len = len(program_input["arr"])
        segments.write_arg(ids.arr, program_input["arr"])
    %}

    reverse(output_ptr, arr_len, arr);
    return ();
}

func test__count_not_zero(output_ptr: felt*) {
    tempvar arr_len: felt;
    let (arr) = alloc();
    %{
        ids.arr_len = len(program_input["arr"])
        segments.write_arg(ids.arr, program_input["arr"])
    %}

    let count = count_not_zero(arr_len, arr);
    assert [output_ptr] = count;
    return ();
}

func test__slice{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar arr_len: felt;
    let (arr) = alloc();
    tempvar offset: felt;
    tempvar size: felt;
    %{
        ids.arr_len = len(program_input["arr"])
        segments.write_arg(ids.arr, program_input["arr"])
        ids.offset = program_input["offset"]
        ids.size = program_input["size"]
    %}

    slice(output_ptr, arr_len, arr, offset, size);
    return ();
}

func test_contains{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar arr_len: felt;
    let (arr) = alloc();
    tempvar value: felt;
    %{
        ids.arr_len = len(program_input["arr"])
        segments.write_arg(ids.arr, program_input["arr"])
        ids.value = program_input["value"]
    %}

    let result = contains(arr_len, arr, value);
    assert [output_ptr] = result;
    return ();
}
