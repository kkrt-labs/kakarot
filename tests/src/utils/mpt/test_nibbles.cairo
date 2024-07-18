from starkware.cairo.common.alloc import alloc
from utils.mpt.nibbles import Nibbles, NibblesImpl

func test__from_bytes{range_check_ptr}() -> Nibbles{
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    let nibbles = NibblesImpl.from_bytes(data_len, data);

    return nibbles;
}

func test__pack_nibbles{range_check_ptr}() -> felt*{
    alloc_locals;
    // Given
    tempvar raw_nibbles_len: felt;
    let (raw_nibbles) = alloc();
    %{
        ids.raw_nibbles_len = len(program_input["nibbles"])
        segments.write_arg(ids.raw_nibbles, program_input["nibbles"])
    %}

    tempvar nibbles = new Nibbles(raw_nibbles_len, raw_nibbles);

    let (bytes:felt*) = alloc();
    let bytes_len = NibblesImpl.pack_nibbles(nibbles, bytes);

    return bytes;
}

func test__encode_path_leaf{range_check_ptr}() -> felt*{
    alloc_locals;
    // Given
    tempvar raw_nibbles_len: felt;
    tempvar is_leaf: felt;
    let (raw_nibbles) = alloc();
    %{
        ids.raw_nibbles_len = len(program_input["nibbles"])
        segments.write_arg(ids.raw_nibbles, program_input["nibbles"])
        ids.is_leaf = program_input["is_leaf"]
    %}

    tempvar nibbles = new Nibbles(raw_nibbles_len, raw_nibbles);

    let (bytes_len, bytes) = NibblesImpl.encode_path_leaf(nibbles, is_leaf);

    return bytes;

}
