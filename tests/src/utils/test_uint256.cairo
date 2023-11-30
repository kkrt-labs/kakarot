// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from utils.uint256 import uint256_to_uint160

@external
func test__uint256_to_uint160{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: Uint256
) -> (uint160: felt) {
    let uint160 = uint256_to_uint160(x);
    return (uint160=uint160);
}
