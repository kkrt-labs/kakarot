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

func test__felt_to_ascii{range_check_ptr}() {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    tempvar ascii: felt*;
    %{ ids.ascii = output %}
    felt_to_ascii(ascii, n);
    return ();
}

func test__felt_to_bytes_little() {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    tempvar bytes: felt*;
    %{ ids.bytes = output %}

    felt_to_bytes_little(bytes, n);
    return ();
}

func test__felt_to_bytes() {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    tempvar bytes: felt*;
    %{ ids.bytes = output %}

    felt_to_bytes(bytes, n);
    return ();
}

func test__felt_to_bytes20{range_check_ptr}() {
    alloc_locals;
    tempvar n: felt;
    %{ ids.n = program_input["n"] %}

    tempvar bytes20: felt*;
    %{ ids.bytes20 = output %}

    felt_to_bytes20(bytes20, n);
    return ();
}

func test__uint256_to_bytes_little{range_check_ptr}() {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    tempvar bytes: felt*;
    %{ ids.bytes = output %}

    uint256_to_bytes_little(bytes, n);
    return ();
}

func test__uint256_to_bytes{range_check_ptr}() {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    tempvar bytes: felt*;
    %{ ids.bytes = output %}

    uint256_to_bytes(bytes, n);
    return ();
}

func test__uint256_to_bytes32{range_check_ptr}() {
    alloc_locals;
    tempvar n: Uint256;
    %{
        ids.n.low = program_input["n"][0]
        ids.n.high = program_input["n"][1]
    %}

    tempvar bytes: felt*;
    %{ ids.bytes = output %}

    uint256_to_bytes32(bytes, n);
    return ();
}

func test__bytes_to_bytes8_little_endian() {
    alloc_locals;
    tempvar bytes_len: felt;
    let (bytes) = alloc();
    %{
        ids.bytes_len = len(program_input["bytes"])
        segments.write_arg(ids.bytes, program_input["bytes"])
    %}

    tempvar res: felt*;
    %{ ids.res = output %}
    bytes_to_bytes8_little_endian(res, bytes_len, bytes);

    return ();
}
