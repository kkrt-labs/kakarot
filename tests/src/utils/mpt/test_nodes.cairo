from starkware.cairo.common.alloc import alloc
from utils.mpt.nibbles import Nibbles, NibblesImpl
from utils.mpt.nodes import (
    LeafNode,
    LeafNodeImpl,
    Bytes,
    ExtensionNode,
    ExtensionNodeImpl,
    BranchNode,
    BranchNodeImpl,
)

func test__leaf_encode{range_check_ptr}() -> Bytes* {
    alloc_locals;
    // Given
    tempvar key_len: felt;
    let (key) = alloc();
    local value: Bytes;

    %{
        ids.key_len = len(program_input["key"])
        segments.write_arg(ids.key, program_input["key"])

        value_len, value_bytes = serde.deserialize_bytes(program_input["value"])
        ids.value.data_len = value_len
        ids.value.data = value_bytes
    %}

    let key_nibbles = NibblesImpl.from_bytes(key_len, key);
    let leaf = LeafNodeImpl.init(key_nibbles, value);

    let encoding = LeafNodeImpl.encode(leaf);

    return encoding;
}

func test__branch_encode{range_check_ptr}() -> Bytes* {
    alloc_locals;
    // Given
    tempvar children_len: felt;
    let (children: Bytes*) = alloc();

    tempvar value: Bytes;
    tempvar new_segments: felt;
    %{
        value_len, value_bytes = serde.deserialize_bytes(program_input["value"])
        ids.value.data_len = value_len
        ids.value.data = value_bytes

        i = 0
        new_segments = 0
        for child in program_input["children"]:
            len_child = len(child)
            memory[ids.children.address_ + i] = len_child
            tmp_segment = segments.add()

            if len_child != 0:
                for j in range(len_child):
                    memory[tmp_segment + j] = child[j]
            memory[ids.children.address_ + i + 1] = tmp_segment
            i+=2
    %}

    let branch = BranchNodeImpl.init(children, value);
    let encoding = BranchNodeImpl.encode(branch);

    return encoding;
}

func test__extension_encode{range_check_ptr}() -> Bytes* {
    alloc_locals;
    // Given
    tempvar key_len: felt;
    let (key) = alloc();

    local child_data_len: felt;
    let (child_data) = alloc();

    %{
        ids.key_len = len(program_input["key"])
        segments.write_arg(ids.key, program_input["key"])

        ids.child_data_len = len(program_input["child"])
        segments.write_arg(ids.child_data, program_input["child"])
    %}

    let key_nibbles = NibblesImpl.from_bytes(key_len, key);
    let extension = ExtensionNodeImpl.init(key_nibbles, new Bytes(child_data_len, child_data));

    let encoding = ExtensionNodeImpl.encode(extension);

    return encoding;
}
