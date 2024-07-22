from utils.mpt.nodes import EncodedNode, LeafNode, LeafNodeImpl, ExtensionNode, ExtensionNodeImpl, BranchNode, BranchNodeImpl
from utils.mpt.nibbles import Nibbles, NibblesImpl
from utils.bytes import uint256_to_bytes32

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le


func patricialize{range_check_ptr}(dict_start: DictAccess*, dict_end: DictAccess*, level: felt) -> EncodedNode*{
    if (dict_start == dict_end){
        let (data) = alloc();
        return new EncodedNode(0, data);
    }

    let key_bytes = get_key_from_entry(dict_start);
    let remaining = dict_end - dict_start;
    if (remaining == DictAccess.SIZE){
        let key_nibbles = NibblesImpl.from_bytes(32, key_bytes);
        let leaf = LeafNodeImpl.init(key_nibbles, dict_start.new_value);
        return leaf;
    }

    let substring = key_bytes + level;
    let prefix_len = 32 - level;

    let prefix_len = find_shortest_common_prefix(dict_start, dict_end, prefix_len, substring);

    // extension node
    let is_extension_node = is_le(1, prefix_len);
    if (is_extension_node != 0) {
        let prefix_len = level + prefix_len;
        let node_key = NibblesImpl.from_bytes(prefix_len, substring);
        let encoded_child = patricialize(dict_start, dict_end, level + prefix_len);
        tempvar extension_node = new ExtensionNode(node_key, encoded_child);
        return extension_node;
    }

    //todo:(wip) handle branches case

}

// @notice Given a pointer to a memory location, returns the u256 [low, high] stored at that location.
func get_key_from_entry{range_check_ptr}(dict_access: DictAccess*) -> felt* {
    alloc_locals;
    let key_ptr = dict_access.key;
    let (bytes) = alloc();
    uint256_to_bytes32(bytes, [cast(key_ptr, Uint256*)]);
    return bytes;
}


func find_shortest_common_prefix{range_check_ptr}(dict_start: DictAccess*, dict_end: DictAccess*, prefix_length: felt, substring: felt*) -> felt{
    if (dict_start == dict_end){
        return prefix_length;
    }

    tempvar entry_ptr;
    %{
        dict_tracker = __dict_manager.get_tracker(ids.dict_ptr)
        dict_tracker.current_ptr += ids.DictAccess.SIZE
        ids.entry_ptr = dict_tracker.data[ids.key]
        breakpoint()
    %}

    let key_bytes = get_key_from_entry(entry_ptr);

    tempvar new_prefix_length;
    %{
        for i in range(prefix_length):
            if memory[ids.substring + i] != memory[ids.key_bytes + i]:
                break
        ids.new_prefix_length = i
    %}
    tempvar prefix_length = new_prefix_length;

    if (prefix_length == 0){
        return 0;
    }

    return find_shortest_common_prefix(entry_ptr + DictAccess.SIZE, dict_end, prefix_length, substring);

}

// # prepare for extension node check by finding max j such that all keys in
// # obj have the same key[i:j]
// substring = arbitrary_key[level:]
// prefix_length = len(substring)
// for key in obj:
//     prefix_length = min(
//         prefix_length, common_prefix_length(substring, key[level:])
//     )

//     # finished searching, found another key at the current level
//     if prefix_length == 0:
//         break

// # if extension node
// if prefix_length > 0:
//     prefix = arbitrary_key[level : level + prefix_length]
//     return ExtensionNode(
//         prefix,
//         encode_internal_node(patricialize(obj, level + prefix_length)),
//     )
