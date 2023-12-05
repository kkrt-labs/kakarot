// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from utils.bytes import (
    felt_to_ascii,
    felt_to_bytes_little,
    felt_to_bytes,
    felt_to_bytes20,
    uint256_to_bytes_little,
    uint256_to_bytes,
    uint256_to_bytes32,
)

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
func test__felt_to_bytes_little{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: felt
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = felt_to_bytes_little(bytes, n);
    return (bytes_len, bytes);
}

@external
func test__felt_to_bytes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: felt
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = felt_to_bytes(bytes, n);
    return (bytes_len, bytes);
}

@external
func test__felt_to_bytes20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: felt
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes20: felt*) = alloc();
    felt_to_bytes20(bytes20, n);
    return (20, bytes20);
}

@external
func test__uint256_to_bytes_little{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: Uint256
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = uint256_to_bytes_little(bytes, n);
    return (bytes_len, bytes);
}

@external
func test__uint256_to_bytes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: Uint256
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    let bytes_len = uint256_to_bytes(bytes, n);
    return (bytes_len, bytes);
}

@external
func test__uint256_to_bytes32{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    n: Uint256
) -> (bytes_len: felt, bytes: felt*) {
    alloc_locals;
    let (bytes: felt*) = alloc();
    uint256_to_bytes32(bytes, n);
    return (32, bytes);
}
