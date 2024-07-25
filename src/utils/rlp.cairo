from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.alloc import alloc

from utils.utils import Helpers

// The namespace handling all RLP computation
namespace RLP {
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

    // Decodes the type of an RLP item.
    // @dev type=0 means the item is a byte array, type=1 means the item is a list.
    // @returns (type, data_offset, data_size) where data_offset is the offset of the data in the
    //  original array and data_size is the size of the data.
    func decode_type{range_check_ptr}(data_len: felt, data: felt*) -> (felt, felt, felt) {
        alloc_locals;

        let prefix = [data];

        // Char
        let is_le_127 = is_nn(0x7f - prefix);
        if (is_le_127 != FALSE) {
            return (0, 0, 1);
        }

        let is_le_183 = is_nn(0xb7 - prefix);  // a max 55 bytes long string
        if (is_le_183 != FALSE) {
            return (0, 1, prefix - 0x80);
        }

        let is_le_191 = is_nn(0xbf - prefix);  // string longer than 55 bytes
        if (is_le_191 != FALSE) {
            local len_bytes_count = prefix - 0xb7;
            let string_len = Helpers.bytes_to_felt(len_bytes_count, data + 1);
            return (0, 1 + len_bytes_count, string_len);
        }

        let is_le_247 = is_nn(0xf7 - prefix);  // list 0-55 bytes long
        if (is_le_247 != FALSE) {
            local list_len = prefix - 0xc0;
            return (1, 1, list_len);
        }

        local len_bytes_count = prefix - 0xf7;
        let list_len = Helpers.bytes_to_felt(len_bytes_count, data + 1);
        return (1, 1 + len_bytes_count, list_len);
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
    func decode{range_check_ptr}(items: Item*, data_len: felt, data: felt*) -> felt {
        alloc_locals;

        if (data_len == 0) {
            return 0;
        }

        let (rlp_type, offset, len) = decode_type(data_len=data_len, data=data);

        if (rlp_type == 1) {
            // Case list
            let (sub_items: Item*) = alloc();
            let sub_items_len = decode(items=sub_items, data_len=len, data=data + offset);
            assert [items] = Item(data_len=sub_items_len, data=cast(sub_items, felt*), is_list=1);
            tempvar range_check_ptr = range_check_ptr;
        } else {
            // Case string or empty list. If the list or string is empty,
            // the data_len is 0 so not passing an empty data segment is fine.
            assert [items] = Item(data_len=len, data=data + offset, is_list=rlp_type);
            tempvar range_check_ptr = range_check_ptr;
        }
        tempvar items = items + Item.SIZE;

        let remaining_data_len = data_len - len - offset;
        let items_len = decode(items=items, data_len=remaining_data_len, data=data + offset + len);
        return 1 + items_len;
    }
}
