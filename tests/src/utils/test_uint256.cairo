%builtins range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from utils.uint256 import uint256_to_uint160, uint256_add, uint256_sub

func test__uint256_to_uint160{range_check_ptr}() {
    // Given
    let (x) = alloc();
    tempvar expected: felt;
    %{
        segments.write_arg(ids.x, program_input["x"])
        ids.expected = program_input["expected"]
    %}

    // When
    let result = uint256_to_uint160([cast(x, Uint256*)]);

    // Then
    assert result = expected;

    return ();
}

func test__uint256_add{range_check_ptr}() -> (felt, felt, felt) {
    alloc_locals;
    let (a_ptr) = alloc();
    let (b_ptr) = alloc();
    %{
        segments.write_arg(ids.a_ptr, program_input["a"])
        segments.write_arg(ids.b_ptr, program_input["b"])
    %}
    let (res, carry) = uint256_add([cast(a_ptr, Uint256*)], [cast(b_ptr, Uint256*)]);

    return (res.low, res.high, carry);
}

func test__uint256_sub{range_check_ptr}() -> Uint256 {
    alloc_locals;
    let (a_ptr) = alloc();
    let (b_ptr) = alloc();
    %{
        segments.write_arg(ids.a_ptr, program_input["a"])
        segments.write_arg(ids.b_ptr, program_input["b"])
    %}
    let (res) = uint256_sub([cast(a_ptr, Uint256*)], [cast(b_ptr, Uint256*)]);

    return res;
}
