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
    let (expected) = alloc();
    %{
        segments.write_arg(ids.data, program_input["data"])
        segments.write_arg(ids.expected, program_input["expected"])
    %}

    // When
    let (tmp: felt*) = alloc();
    let (_, result: felt*) = Helpers.bytes_to_bytes4_array(12, data, 0, tmp);

    // Then
    assert expected[0] = result[0];
    assert expected[1] = result[1];
    assert expected[2] = result[2];

    return ();
}

func test__bytes4_array_to_bytes{range_check_ptr}() {
    alloc_locals;
    // Given
    let (data) = alloc();
    let (expected) = alloc();
    %{
        segments.write_arg(ids.data, program_input["data"])
        segments.write_arg(ids.expected, program_input["expected"])
    %}

    // When
    let (tmp) = alloc();
    let (_, result) = Helpers.bytes4_array_to_bytes(3, data, 0, tmp);

    // Then
    assert result[0] = expected[0];
    assert result[1] = expected[1];
    assert result[2] = expected[2];
    assert result[3] = expected[3];
    assert result[4] = expected[4];
    assert result[5] = expected[5];
    assert result[6] = expected[6];
    assert result[7] = expected[7];
    assert result[8] = expected[8];
    assert result[9] = expected[9];
    assert result[10] = expected[10];
    assert result[11] = expected[11];

    return ();
}

func test__bytes_used_128{range_check_ptr}(output_ptr: felt*) {
    tempvar word;
    %{ ids.word = program_input["word"] %}

    // When
    let bytes_used = Helpers.bytes_used_128(word);

    // Then
    assert [output_ptr] = bytes_used;
    return ();
}

func test__try_parse_destination_from_bytes{range_check_ptr}(output_ptr: felt*) {
    let (bytes) = alloc();
    tempvar bytes_len;
    %{
        segments.write_arg(ids.bytes, program_input["bytes"])
        ids.bytes_len = len(program_input["bytes"])
    %}

    // When
    let maybe_address = Helpers.try_parse_destination_from_bytes(bytes_len, bytes);

    // Then
    assert [output_ptr] = maybe_address.is_some;
    assert [output_ptr + 1] = maybe_address.value;

    return ();
}
