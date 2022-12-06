// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

// Local dependencies
from utils.utils import Helpers

from tests.utils.utils import TestHelpers

@external
func test__bytes_i_to_uint256{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    let (bytecode) = alloc();
    assert bytecode[0] = 0x01;
    assert bytecode[1] = 0x02;

    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 1);

    assert_uint256_eq(
        uint256,
        Uint256(0x01, 0)
    );

    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 2);

    assert_uint256_eq(
        uint256,
        Uint256(0x0102, 0)
    );

    let (bytecode) = alloc();
    TestHelpers._fill_bytecode_with_values(bytecode, 20, 0xFF);
    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 20);

    assert_uint256_eq(
        uint256,
        Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFF)
    );

    let (bytecode) = alloc();
    TestHelpers._fill_bytecode_with_values(bytecode, 16, 0xFF);
    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 16);

    assert_uint256_eq(
        uint256,
        Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0)
    );

    return ();
}
