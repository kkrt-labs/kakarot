from starkware.cairo.common.alloc import alloc
from utils.mpt.nibbles import Nibbles, NibblesImpl
from utils.mpt.nodes import (
    LeafNode,
    LeafNodeImpl,
    EncodedNode,
    ExtensionNode,
    ExtensionNodeImpl,
    BranchNode,
    BranchNodeImpl,
)

func test__leaf_encode{range_check_ptr}() -> EncodedNode* {
    alloc_locals;
    // Given
    tempvar key_len: felt;
    let (key) = alloc();
    local value_len: felt;
    let (value) = alloc();

    %{
        ids.key_len = len(program_input["key"])
        segments.write_arg(ids.key, program_input["key"])

        ids.value_len = len(program_input["value"])
        segments.write_arg(ids.value, program_input["value"])
    %}

    let key_nibbles = NibblesImpl.from_bytes(key_len, key);
    let leaf = LeafNodeImpl.init(key_nibbles, value_len, value);

    let encoding = LeafNodeImpl.encode(leaf);

    return encoding;
}

func test__branch_encode{range_check_ptr}() -> EncodedNode* {
    alloc_locals;
    // Given
    tempvar children_len: felt;
    let (children: EncodedNode*) = alloc();

    tempvar value_len: felt;
    let (value) = alloc();

    tempvar new_segments: felt;
    %{
        ids.value_len = len(program_input["value"])
        segments.write_arg(ids.value, program_input["value"])

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

    let branch = BranchNodeImpl.init(children, value_len, value);
    let encoding = BranchNodeImpl.encode(branch);

    return encoding;
}

func test__extension_encode{range_check_ptr}() -> EncodedNode* {
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
    let extension = ExtensionNodeImpl.init(
        key_nibbles, new EncodedNode(child_data_len, child_data)
    );

    let encoding = ExtensionNodeImpl.encode(extension);

    return encoding;
}
