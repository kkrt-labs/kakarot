from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from utils.bytes import uint256_to_bytes32

func test_abc{range_check_ptr}(){
    alloc_locals;
    tempvar new_key1 = new Uint256(0x12345678,0);
    tempvar new_key2 = new Uint256(0x12345679, 0);
    let (local db_start) = default_dict_new(0);
    let db = db_start;

    dict_write{dict_ptr=db}(cast(new_key1,felt), 1);
    dict_write{dict_ptr=db}(cast(new_key2,felt), 1);

    let level = 0;
    let key_bytes = get_key_from_entry(db_start);
    let substring = key_bytes + level;
    let prefix_len = 32 - level;
    %{breakpoint()%}

    let prefix_len = find_shortest_common_prefix(db_start, db, prefix_len, substring);

    // extension node
    let is_extension_node = is_le(1, prefix_len);
    if (is_extension_node) {
        let prefix_len = level + prefix_len
        tempvar extension_node = new ExtensionNode(shortest_common_prefix, data);
        return extension_node;
    }

    return();
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
    let key_bytes = get_key_from_entry(dict_start);

    tempvar new_prefix_length;
    %{
        new_prefix_length = ids.prefix_length
        for i in range(ids.prefix_length):
            print(f" {memory[ids.substring + i]} - {memory[ids.key_bytes + i]}")
            if memory[ids.substring + i] != memory[ids.key_bytes + i]:
                new_prefix_length = i
                break
        ids.new_prefix_length = new_prefix_length
    %}
    tempvar prefix_length = new_prefix_length;

    if (prefix_length == 0){
        return 0;
    }

    return find_shortest_common_prefix(dict_start + DictAccess.SIZE, dict_end, prefix_length, substring);

}
