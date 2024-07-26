from utils.mpt.nodes import (
    EncodedNode,
    LeafNode,
    LeafNodeImpl,
    ExtensionNode,
    ExtensionNodeImpl,
    BranchNode,
    BranchNodeImpl,
)
from utils.mpt.nibbles import Nibbles, NibblesImpl
from utils.bytes import uint256_to_bytes32

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le

func patricialize{range_check_ptr}(
    dict_start: DictAccess*, dict_end: DictAccess*, level: felt
) -> EncodedNode* {
    alloc_locals;
    if (dict_start == dict_end) {
        let (data) = alloc();
        return new EncodedNode(0, data);
    }

    let (key_len, key) = get_key_from_entry(dict_start);
    let remaining = dict_end - dict_start;
    if (remaining == DictAccess.SIZE) {
        let key_nibbles = NibblesImpl.from_bytes(key_len, key);
        let (value_len, value) = get_value_from_entry(dict_start);
        let leaf = LeafNodeImpl.init(key_nibbles, value_len, value);
        let encoded_leaf = LeafNodeImpl.encode(leaf);
        return encoded_leaf;
    }

    let substring = key + level;
    let prefix_len = 32 - level;

    let prefix_len = find_shortest_common_prefix(
        dict_start, dict_end, prefix_len, substring, level
    );

    // extension node
    let is_extension_node = is_le(1, prefix_len);
    if (is_extension_node != 0) {
        let prefix_len = level + prefix_len;
        let node_key = NibblesImpl.from_bytes(prefix_len, substring);
        let encoded_child = patricialize(dict_start, dict_end, level + prefix_len);
        tempvar extension_node = ExtensionNodeImpl.init(node_key, encoded_child);
        let encoded_extension = ExtensionNodeImpl.encode(extension_node);
        return encoded_extension;
    }

    local branch_ptr_start: DictAccess*;
    local branch_ptr: DictAccess*;
    local value_len: felt;
    let (value) = alloc();
    // branch node
    %{
        # gets an object k:v with the segment indexes
        obj_serialized = serde.serialize_dict(ids.dict_start.address_, dict_size=(ids.dict_end.address_ - ids.dict_start.address_)//3)

        # serialize the lists of keys and values back to bytes
        obj = {}
        for key in obj_serialized:
            key_segment = key
            value_segment = obj_serialized[key]

            key_bytes = []
            for i in range(32):
                try:
                    key_bytes.append(memory[key_segment + i])
                except:
                    break

            value_bytes = []
            for i in range(32):
                try:
                    value_bytes.append(memory[value_segment + i])
                except:
                    break

            obj[bytes(key_bytes)] = bytes(value_bytes)

        branches = []
        for _ in range(16):
            branches.append({})
        value = b""
        for key in obj:
            if len(key) == ids.level:
                value = obj[key]
            else:
                branches[key[ids.level]][key] = obj[key]

        ids.branch_ptr_start, ids.branch_ptr = serde.deserialize_dict(branches, __dict_manager)
        ids.value_len = len(value)
        segments.write_arg(ids.value_ptr, value)
    %}

    // TODO: encode all children nodes of the branch node

    return cast(0, EncodedNode*);
}

// @notice Given a pointer to a memory location, returns the u256 [low, high] stored at that location.
func get_key_from_entry{range_check_ptr}(dict_access: DictAccess*) -> (felt, felt*) {
    alloc_locals;
    let key_len = [dict_access.key];
    let key = cast([dict_access.key + 1], felt*);
    return (key_len, key);
}

func get_value_from_entry{range_check_ptr}(dict_access: DictAccess*) -> (felt, felt*) {
    alloc_locals;
    let value_len = [dict_access.new_value];
    let value = cast([dict_access.new_value + 1], felt*);
    return (value_len, value);
}

func find_shortest_common_prefix{range_check_ptr}(
    dict_start: DictAccess*,
    dict_end: DictAccess*,
    prefix_length: felt,
    substring: felt*,
    level: felt,
) -> felt {
    if (dict_start == dict_end) {
        return prefix_length;
    }

    tempvar shortest_prefix_length;
    %{
        def common_prefix_length(a, b) -> int:
            """
            Find the longest common prefix of two sequences.
            """
            for i in range(len(a)):
                if i >= len(b) or a[i] != b[i]:
                    return i
            return len(a)


        # gets an object k:v with the segment indexes
        obj_serialized = serde.serialize_dict(ids.dict_start.address_, dict_size=(ids.dict_end.address_ - ids.dict_start.address_)//3)

        # serialize the lists of keys and values back to bytes
        obj = {}
        for key in obj_serialized:
            key_segment = key
            value_segment = obj_serialized[key]

            key_bytes = []
            for i in range(32):
                try:
                    key_bytes.append(memory[key_segment + i])
                except:
                    break

            value_bytes = []
            for i in range(32):
                try:
                    value_bytes.append(memory[value_segment + i])
                except:
                    break

            obj[bytes(key_bytes)] = bytes(value_bytes)


        prefix_length = ids.prefix_length

        substring = serde.serialize_list(ids.substring, list_len=4)
        for key in obj:
            prefix_length = min(
                prefix_length, common_prefix_length(substring, key[ids.level:])
            )

            # finished searching, found another key at the current level
            if prefix_length == 0:
                break

        ids.shortest_prefix_length = prefix_length
    %}

    return shortest_prefix_length;
}
