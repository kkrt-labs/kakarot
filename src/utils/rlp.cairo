from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math_cmp import is_le
from utils.utils import Helpers

// The namespace handling all RLP computation
namespace RLP {
    // The type returned when data is RLP decoded
    struct Item {
        data_len: felt,
        data: felt*,
        is_list: felt,  // when is TRUE the data must be RLP decoded
    }

    // @notice decodes RLP data see this: https://ethereum.org/en/developers/docs/data-structures-and-encoding/rlp
    // @param data_len The length of the bytes
    // @param data The pointer to the first byte in array
    // @param items A pointer to an empty array of items, will be filled with found items
    func decode{range_check_ptr}(data_len: felt, data: felt*, items: Item*) -> () {
        alloc_locals;
        if (data_len == 0) {
            return ();
        }

        tempvar byte = [data];
        let is_le_127 = is_le(byte, 127);
        if (is_le_127 != FALSE) {
            assert [items] = Item(data_len=1, data=data, is_list=0);
            return decode(data_len=data_len - 1, data=data + 1, items=items + Item.SIZE);
        }

        let data = data + 1;
        let is_le_183 = is_le(byte, 183);  // a max 55 bytes long string
        if (is_le_183 != FALSE) {
            let string_len = byte - 128;
            assert [items] = Item(data_len=string_len, data=data, is_list=0);
            return decode(
                data_len=data_len - 1 - string_len, data=data + string_len, items=items + Item.SIZE
            );
        }

        let is_le_191 = is_le(byte, 191);  // string longer than 55 bytes
        if (is_le_191 != FALSE) {
            local len_len = byte - 183;
            let dlen = Helpers.bytes_to_felt(len_len, data);
            let data = data + len_len;
            assert [items] = Item(data_len=dlen, data=data, is_list=0);
            return decode(
                data_len=data_len - 1 - len_len - dlen, data=data + dlen, items=items + Item.SIZE
            );
        }

        let is_le_247 = is_le(byte, 247);  // list 0-55 bytes long
        if (is_le_247 != FALSE) {
            local list_len = byte - 192;
            assert [items] = Item(data_len=list_len, data=data, is_list=1);
            return decode(
                data_len=data_len - 1 - list_len, data=data + list_len, items=items + Item.SIZE
            );
        }

        local list_len_len = byte - 247;
        let dlen = Helpers.bytes_to_felt(list_len_len, data);
        let data = data + list_len_len;
        assert [items] = Item(data_len=dlen, data=data, is_list=1);
        return decode(
            data_len=data_len - 1 - list_len_len - dlen, data=data + dlen, items=items + Item.SIZE
        );
    }
}
