%builtins range_check

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
    bytes_to_bytes8_little_endian,
)

func test__felt_to_ascii{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    felt_to_ascii(output_ptr, n);
    return ();
}

func test__felt_to_bytes_little{range_check_ptr}() -> felt* {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    let (output) = alloc();
    felt_to_bytes_little(output, n);
    return output;
}

func test__felt_to_bytes{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    felt_to_bytes(output_ptr, n);
    return ();
}

func test__felt_to_bytes20{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    felt_to_bytes20(output_ptr, n);
    return ();
}

func test__uint256_to_bytes_little{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    uint256_to_bytes_little(output_ptr, n);
    return ();
}

func test__uint256_to_bytes{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    uint256_to_bytes(output_ptr, n);
    return ();
}

func test__uint256_to_bytes32{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    uint256_to_bytes32(output_ptr, n);
    return ();
}

func test__bytes_to_bytes8_little_endian{range_check_ptr}() -> (felt*, felt, felt) {
    alloc_locals;
    tempvar bytes_len: felt;
    let (bytes) = alloc();
    %{
        ids.bytes_len = len(program_input["bytes"])
        segments.write_arg(ids.bytes, program_input["bytes"])
    %}

    let (bytes8) = alloc();
    let (bytes8_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
        bytes8, bytes_len, bytes
    );

    return (bytes8, last_word, last_word_num_bytes);
}
