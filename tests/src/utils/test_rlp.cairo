%builtins range_check

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

func test__decode{range_check_ptr}() {
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
    RLP.decode(data_len, data, items);

    // Then
    let item = items[0];
    tempvar is_list: felt;
    %{ ids.is_list = program_input["is_list"] %}
    assert item.is_list = is_list;

    tempvar output: felt*;
    %{ ids.output = output %}
    memcpy(output, item.data, item.data_len);

    return ();
}
