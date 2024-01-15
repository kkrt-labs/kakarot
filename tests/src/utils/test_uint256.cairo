%builtins range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from utils.uint256 import uint256_to_uint160

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
