%builtins range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.memset import memset

from utils.utils import Helpers

func test__bytes_i_to_uint256{range_check_ptr}() {
    alloc_locals;

    let (bytecode) = alloc();
    assert bytecode[0] = 0x01;
    assert bytecode[1] = 0x02;

    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 1);

    assert_uint256_eq(uint256, Uint256(0x01, 0));

    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 2);

    assert_uint256_eq(uint256, Uint256(0x0102, 0));

    let (bytecode) = alloc();
    memset(bytecode, 0xFF, 20);
    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 20);

    assert_uint256_eq(uint256, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFF));

    let (bytecode) = alloc();
    memset(bytecode, 0xFF, 16);
    let uint256 = Helpers.bytes_i_to_uint256(bytecode, 16);

    assert_uint256_eq(uint256, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0));

    return ();
}

func test__bytes_to_bytes4_array{range_check_ptr}() {
    alloc_locals;
    // Given
    let (data) = alloc();
    assert data[0] = 0x68;
    assert data[1] = 0x65;
    assert data[2] = 0x6c;
    assert data[3] = 0x6c;
    assert data[4] = 0x6f;
    assert data[5] = 0x20;
    assert data[6] = 0x77;
    assert data[7] = 0x6f;
    assert data[8] = 0x72;
    assert data[9] = 0x6c;
    assert data[10] = 0x64;
    assert data[11] = 0x00;

    // When
    let (expected: felt*) = alloc();
    let (_, expected: felt*) = Helpers.bytes_to_bytes4_array(12, data, 0, expected);

    // Then
    assert expected[0] = 0x68656c6c;
    assert expected[1] = 0x6f20776f;
    assert expected[2] = 0x726c6400;

    return ();
}

func test__bytes4_array_to_bytes{range_check_ptr}() {
    alloc_locals;
    // Given
    let (data) = alloc();
    assert data[0] = 0x68656c6c;
    assert data[1] = 0x6f20776f;
    assert data[2] = 0x726c6400;

    // When
    let (expected: felt*) = alloc();
    let (_, expected: felt*) = Helpers.bytes4_array_to_bytes(3, data, 0, expected);

    // Then
    assert expected[0] = 0x68;
    assert expected[1] = 0x65;
    assert expected[2] = 0x6c;
    assert expected[3] = 0x6c;
    assert expected[4] = 0x6f;
    assert expected[5] = 0x20;
    assert expected[6] = 0x77;
    assert expected[7] = 0x6f;
    assert expected[8] = 0x72;
    assert expected[9] = 0x6c;
    assert expected[10] = 0x64;
    assert expected[11] = 0x00;

    return ();
}

func main{range_check_ptr}() {
    test__bytes_i_to_uint256();
    test__bytes_to_bytes4_array();
    test__bytes4_array_to_bytes();
    return ();
}
