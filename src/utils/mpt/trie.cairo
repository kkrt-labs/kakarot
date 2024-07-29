from utils.mpt.nodes import (
    Bytes,
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
) -> Bytes* {
    alloc_locals;
    if (dict_start == dict_end) {
        let (data) = alloc();
        return new Bytes(0, data);
    }

    let (key_len, key) = get_key_from_entry(dict_start);
    let remaining = dict_end - dict_start;
    if (remaining == DictAccess.SIZE) {
        tempvar key_nibbles = new Nibbles(key_len, key);
        let value = get_value_from_entry(dict_start);
        let leaf = LeafNodeImpl.init(key_nibbles, [value]);
        let encoded_leaf = LeafNodeImpl.encode(leaf);
        return encoded_leaf;
    }

    let substring = key + level;
    let prefix_len = key_len - level;

    let prefix_len = find_shortest_common_prefix(
        dict_start, dict_end, prefix_len, substring, level
    );

    // extension node
    let is_extension_node = is_le(1, prefix_len);
    if (is_extension_node != 0) {
        tempvar node_key = new Nibbles(nibbles_len=level + prefix_len, nibbles=substring);
        let encoded_child = patricialize(dict_start, dict_end, level + prefix_len);
        tempvar extension_node = ExtensionNodeImpl.init(node_key, encoded_child);
        let encoded_extension = ExtensionNodeImpl.encode(extension_node);
        return encoded_extension;
    }

    tempvar children_len: felt;
    tempvar children: Bytes*;
    tempvar branch_value: Bytes;
    // branch node
    %{
        from ethereum.cancun.trie import patricialize, encode_internal_node
        # gets an object k:v with the segment indexes
        obj_serialized = serde.serialize_dict(ids.dict_start.address_, dict_size=(ids.dict_end.address_ - ids.dict_start.address_))

        # serialize the lists of keys and values back to bytes
        obj = {}
        for key in obj_serialized:
            key_bytes = serde.serialize_bytes(key)
            value_bytes = serde.serialize_bytes(obj_serialized[key])
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

        subnodes = [encode_internal_node(patricialize(branches[k], ids.level + 1)) for k in range(16)]
        serialized_subnodes = [b"".join(subnode) if isinstance(subnode, tuple) else subnode for subnode in subnodes]
        children_len, children = serde.deserialize_bytes_list(serialized_subnodes)
        value_len, value = serde.deserialize_bytes(value)

        ids.children_len = children_len
        ids.children = children
        ids.branch_value.data_len = value_len
        ids.branch_value.data = value
    %}
    let branch = BranchNodeImpl.init(children, branch_value);
    let encoded_branch = BranchNodeImpl.encode(branch);
    return encoded_branch;
}

// @notice Given a pointer to a memory location, returns the u256 [low, high] stored at that location.
func get_key_from_entry{range_check_ptr}(dict_access: DictAccess*) -> (felt, felt*) {
    alloc_locals;
    let key_len = [dict_access.key];
    let key = cast([dict_access.key + 1], felt*);
    return (key_len, key);
}

func get_value_from_entry{range_check_ptr}(dict_access: DictAccess*) -> Bytes* {
    alloc_locals;
    let value_len = [dict_access.new_value];
    let value = cast([dict_access.new_value + 1], felt*);
    return new Bytes(value_len, value);
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
        obj_serialized = serde.serialize_dict(ids.dict_start.address_, dict_size=(ids.dict_end.address_ - ids.dict_start.address_))

        # serialize the lists of keys and values back to bytes
        obj = {}
        for key in obj_serialized:
            key_bytes = serde.serialize_bytes(key)
            value_bytes = serde.serialize_bytes(obj_serialized[key])
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
