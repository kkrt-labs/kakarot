// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from utils.bytes import felt_to_ascii, bytes_to_bytes8_little_endian

@external
func test__felt_to_ascii{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: felt
) -> (ascii_len: felt, ascii: felt*) {
    alloc_locals;
    let (ascii: felt*) = alloc();
    let ascii_len = felt_to_ascii(ascii, n);
    return (ascii_len, ascii);
}

@external
func test__bytes_to_bytes8_little_endian{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(bytes_len: felt, bytes: felt*) -> (res_len: felt, res: felt*) {
    alloc_locals;
    let (res: felt*) = alloc();
    let res_len = bytes_to_bytes8_little_endian(res, bytes_len, bytes);
    return (res_len, res);
}
