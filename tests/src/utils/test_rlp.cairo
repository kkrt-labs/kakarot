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
    let (items_len, items) = RLP.decode(data_len, data);

    %{
        def flatten_list(address, len, output_offset, list_level):
            print(f"List level {list_level}")
            for i in range(len):
                data_len = memory[address + i*3]
                data_ptr = memory[address + i*3 + 1]
                is_list = memory[address +i*3 + 2]

                if is_list:
                    list_level = list_level + 1
                    flatten_list(data_ptr, data_len, output_offset, list_level)
                else:
                    bytes = []
                    for j in range(data_len):
                        byte = memory[data_ptr + j]
                        bytes.append(byte)
                        memory[ids.output_ptr + output_offset] = byte
                        output_offset += 1
                    print(f"String number {i}: {bytes}")


        for i in range(ids.items_len):
            address = ids.items[i].address_
            len = ids.items_len
            flatten_list(address, len, 0, list_level=0)
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
    let (items_len, items) = RLP.decode(data_len, data);

    %{
        def flatten_list(address, len, output_offset, list_level):
            print(f"List level {list_level}")
            for i in range(len):
                data_len = memory[address + i*3]
                data_ptr = memory[address + i*3 + 1]
                is_list = memory[address +i*3 + 2]

                if is_list:
                    list_level = list_level + 1
                    flatten_list(data_ptr, data_len, output_offset, list_level)
                else:
                    bytes = []
                    for j in range(data_len):
                        byte = memory[data_ptr + j]
                        bytes.append(byte)
                        memory[ids.output_ptr + output_offset] = byte
                        output_offset += 1
                    print(f"String number {i}: {bytes}")


        for i in range(ids.items_len):
            address = ids.items[i].address_
            len = ids.items_len
            flatten_list(address, len, 0, list_level=0)
    %}
    return ();
}
