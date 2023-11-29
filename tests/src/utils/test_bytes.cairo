// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from utils.bytes import felt_to_ascii

@external
func test__felt_to_ascii{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: felt
) -> (ascii_len: felt, ascii: felt*) {
    let (ascii_len, ascii) = felt_to_ascii(n);
    return (ascii_len, ascii);
}
