from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.math import assert_not_zero, assert_nn
from starkware.cairo.common.alloc import alloc

from utils.utils import Helpers

// The namespace handling all RLP computation
namespace RLP {
    const TYPE_STRING = 0;
    const TYPE_LIST = 1;

    // The type returned when data is RLP decoded
    // An RLP Item is either a byte array or a list of other RLP Items.
    // The data is either a pointer to the first byte in the array or a pointer to the first Item in the list.
    // If the data is a list then the data_len is the number of items in the list.
    // and the `data` field can be casted to a `Item*` to access the bytes.
    // If the data is a byte array then the data_len is the length of the array.
    struct Item {
        data_len: felt,
        data: felt*,
        is_list: felt,
    }

    // @notive Decode the type of an RLP item.
    // @dev Unsafe function, does not check if the data is long enough (can be exploited by a malicious prover).
    //      Always check afterwards that outputs are compatible with the associated data_len.
    // @param data The RLP encoded data.
    // @return rlp_type The type of the RLP data (string or list).
    // @return offset The offset of the data in the RLP encoded data.
    // @return len The length of the data.
    func decode_type_unsafe{range_check_ptr}(data: felt*) -> (
        rlp_type: felt, offset: felt, len: felt
    ) {
        alloc_locals;

        let prefix = [data];

        // Char
        let is_le_127 = is_nn(0x7f - prefix);
        if (is_le_127 != FALSE) {
            return (TYPE_STRING, 0, 1);
        }

        let is_le_183 = is_nn(0xb7 - prefix);  // a max 55 bytes long string
        if (is_le_183 != FALSE) {
            return (TYPE_STRING, 1, prefix - 0x80);
        }

        let is_le_191 = is_nn(0xbf - prefix);  // string longer than 55 bytes
        if (is_le_191 != FALSE) {
            local len_bytes_count = prefix - 0xb7;
            let string_len = Helpers.bytes_to_felt(len_bytes_count, data + 1);
            assert [range_check_ptr] = string_len;
            let range_check_ptr = range_check_ptr + 1;
            return (TYPE_STRING, 1 + len_bytes_count, string_len);
        }

        let is_le_247 = is_nn(0xf7 - prefix);  // list 0-55 bytes long
        if (is_le_247 != FALSE) {
            local list_len = prefix - 0xc0;
            return (TYPE_LIST, 1, list_len);
        }

        local len_bytes_count = prefix - 0xf7;
        let list_len = Helpers.bytes_to_felt(len_bytes_count, data + 1);
        tempvar offset = 1 + len_bytes_count;
        assert [range_check_ptr] = offset;
        assert [range_check_ptr + 1] = list_len;
        let range_check_ptr = range_check_ptr + 2;
        return (TYPE_LIST, offset, list_len);
    }

    // @notice Decodes a Recursive Length Prefix (RLP) encoded data.
    // @notice This function decodes the RLP encoded data into a list of items.
    // Each item is a struct containing the length of the data, the data itself, and a flag indicating whether the data is a list.
    // The function first determines the type of the RLP data (string or list) and then processes it accordingly.
    // If the data is a string, it is simply added to the items.
    // If the data is a list, it is recursively decoded.
    // After processing the first item, the function checks if there is more data to decode and if so,
    // it recursively decodes the remaining data and adds the decoded items to the list of items.
    // @param data_len The length of the data to decode.
    // @param data The RLP encoded data.
    // @param items The pointer to the next free cell in the list of items decoded.
    // @return items_len The number of items decoded.
    func decode_raw{range_check_ptr}(items: Item*, data_len: felt, data: felt*) -> felt {
        alloc_locals;

        if (data_len == 0) {
            return 0;
        }

        with_attr error_message("RLP data too short for declared length") {
            let (rlp_type, offset, len) = decode_type_unsafe(data);
            assert [range_check_ptr] = offset + len;
            local remaining_data_len = data_len - [range_check_ptr];
            let range_check_ptr = range_check_ptr + 1;
            assert_nn(remaining_data_len);
        }

        if (rlp_type == TYPE_LIST) {
            let (sub_items: Item*) = alloc();
            let sub_items_len = decode_raw(items=sub_items, data_len=len, data=data + offset);
            assert [items] = Item(sub_items_len, cast(sub_items, felt*), TRUE);
            tempvar range_check_ptr = range_check_ptr;
        } else {
            assert [items] = Item(data_len=len, data=data + offset, is_list=FALSE);
            tempvar range_check_ptr = range_check_ptr;
        }
        tempvar items = items + Item.SIZE;

        let items_len = decode_raw(
            items=items, data_len=remaining_data_len, data=data + offset + len
        );
        return 1 + items_len;
    }

    func decode{range_check_ptr}(items: Item*, data_len: felt, data: felt*) {
        alloc_locals;
        let (rlp_type, offset, len) = decode_type_unsafe(data);
        local extra_bytes = data_len - offset - len;
        with_attr error_message("RLP string ends with {extra_bytes} superfluous bytes") {
            assert extra_bytes = 0;
        }
        let items_len = decode_raw(items=items, data_len=data_len, data=data);
        assert items_len = 1;
        return ();
    }
}
