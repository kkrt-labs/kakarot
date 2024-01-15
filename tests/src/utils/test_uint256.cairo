%builtins range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

from utils.uint256 import uint256_to_uint160

func test__uint256_to_uint160{range_check_ptr}(x: Uint256, expected: felt) {
    // When
    let result = uint256_to_uint160(x);

    // Then
    assert result = expected;

    return ();
}
