from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from utils.mpt.nodes import EncodedNode
from utils.mpt.trie import find_shortest_common_prefix, patricialize
from utils.bytes import uint256_to_bytes32

func test__patricialize{range_check_ptr}() -> EncodedNode* {
    alloc_locals;
    local dict_ptr_start: DictAccess*;
    local dict_ptr: DictAccess*;
    let level = 0;
    %{
        if '__dict_manager' not in globals():
            from starkware.cairo.common.dict import DictManager
            __dict_manager = DictManager()

        obj = program_input["objects"]
        ids.dict_ptr_start, ids.dict_ptr = serde.deserialize_dict(obj, __dict_manager)
    %}

    let patricialized = patricialize(dict_ptr_start, dict_ptr, level);

    return patricialized;
}

func test__find_shortest_common_prefix{range_check_ptr}() -> felt {
    alloc_locals;

    local dict_ptr_start: DictAccess*;
    local dict_ptr: DictAccess*;
    let (substring) = alloc();
    %{
        if '__dict_manager' not in globals():
            from starkware.cairo.common.dict import DictManager
            __dict_manager = DictManager()

        obj = program_input["objects"]
        ids.dict_ptr_start, ids.dict_ptr = serde.deserialize_dict(obj, __dict_manager)
        segments.write_arg(ids.substring, program_input["substring"])
    %}

    let shortest = find_shortest_common_prefix(dict_ptr_start, dict_ptr, 32, substring, 0);

    return shortest;
}

// // @notice Given a pointer to a memory location, returns the u256 [low, high] stored at that location.
// func get_key_from_entry{range_check_ptr}(dict_access: DictAccess*) -> felt* {
//     alloc_locals;
//     let key_ptr = dict_access.key;
//     let (bytes) = alloc();
//     uint256_to_bytes32(bytes, [cast(key_ptr, Uint256*)]);
//     return bytes;
// }
