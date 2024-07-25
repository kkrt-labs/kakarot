%builtins range_check

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

func test__decode{range_check_ptr}() -> (items_len: felt, items: RLP.Item*) {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    // When
    let (local items: RLP.Item*) = alloc();
    let items_len = RLP.decode(items, data_len, data);

    return (items_len, items);
}

func test__decode_type{range_check_ptr}() -> (felt, felt, felt) {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    // When
    let (type, offset, len) = RLP.decode_type(data_len, data);

    // Then
    return (type, offset, len);
}
