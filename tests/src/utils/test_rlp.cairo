%builtins range_check

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

func test__decode{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    // When
    let items_len = 0;
    let (items: RLP.Item*) = alloc();
    with items_len, items {
        RLP.decode(data_len, data);
    }
    %{
        from tests.utils.hints import flatten_list
        # The cairo functions returns a single RLP list of size 1 containing the decoded objects.
        flatten_list(ids.items[0].address_, 1, ids.output_ptr, memory, segments)
    %}
    return ();
}

func test__decode_type{range_check_ptr}(output_ptr: felt*) {
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
    assert [output_ptr] = type;
    assert [output_ptr + 1] = offset;
    assert [output_ptr + 2] = len;

    return ();
}

func test__decode_transaction{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    // When
    let items_len = 0;
    let (items: RLP.Item*) = alloc();
    with items_len, items {
        RLP.decode(data_len, data);
    }

    %{
        from tests.utils.hints import flatten_list
        # The cairo functions returns a single RLP list of size 1 containing the decoded objects.
        flatten_list(ids.items[0].address_, 1, ids.output_ptr, memory, segments)
    %}
    return ();
}
