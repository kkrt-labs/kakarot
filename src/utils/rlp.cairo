// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.pow import pow
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import word_reverse_endian
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
    // @param data_len The lenght of the bytes
    // @param data The pointer to the first byte in array
    // @param items A pointer to an empty array of items, will be filled with found items
    func decode_rlp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(data_len: felt, data: felt*, items: Item*) -> () {
        alloc_locals;
        if (data_len == 0) {
            return ();
        }
        let buffer_ptr = data;
        with buffer_ptr {
            tempvar byte = [buffer_ptr];
            let buffer_ptr = buffer_ptr + 1;
            let is_le_127: felt = is_le(byte, 127);
            if (is_le_127 != FALSE) {
                assert [items] = Item(
                    data_len=1,
                    data=buffer_ptr - 1,
                    is_list=0
                    );
                return decode_rlp(data_len=data_len - 1, data=buffer_ptr, items=items + Item.SIZE);
            }
            let is_le_183 = is_le(byte, 183);  // a max 55 bytes long string
            if (is_le_183 != FALSE) {
                let string_len = byte - 128;
                assert [items] = Item(
                    data_len=string_len,
                    data=buffer_ptr,
                    is_list=0
                    );
                return decode_rlp(
                    data_len=data_len - 1 - string_len,
                    data=buffer_ptr + string_len,
                    items=items + Item.SIZE,
                );
            }
            let is_le_191 = is_le(byte, 191);  // string longer than 55 bytes
            if (is_le_191 != FALSE) {
                local len_len = byte - 183;
                let (dlen) = Helpers.bytes_to_felt(data_len=len_len, data=buffer_ptr, n=0);
                let buffer_ptr = buffer_ptr + len_len;
                assert [items] = Item(
                    data_len=dlen,
                    data=buffer_ptr,
                    is_list=0
                    );
                return decode_rlp(
                    data_len=data_len - 1 - len_len - dlen,
                    data=buffer_ptr + dlen,
                    items=items + Item.SIZE,
                );
            }
            let is_le_247 = is_le(byte, 247);  // list 0-55 bytes long
            if (is_le_247 != FALSE) {
                local list_len = byte - 192;
                assert [items] = Item(
                    data_len=list_len,
                    data=buffer_ptr,
                    is_list=1
                    );
                return decode_rlp(
                    data_len=data_len - 1 - list_len,
                    data=buffer_ptr + list_len,
                    items=items + Item.SIZE,
                );
            }
            let is_le_255 = is_le(byte, 255);  // list > 55 bytes
            if (is_le_255 != FALSE) {
                local list_len_len = byte - 247;
                let (dlen) = Helpers.bytes_to_felt(data_len=list_len_len, data=buffer_ptr, n=0);
                let buffer_ptr = buffer_ptr + list_len_len;
                assert [items] = Item(
                    data_len=dlen,
                    data=buffer_ptr,
                    is_list=1
                    );
                return decode_rlp(
                    data_len=data_len - 1 - list_len_len - dlen,
                    data=buffer_ptr + dlen,
                    items=items + Item.SIZE,
                );
            }
            return ();
        }
    }

    // @notice encodes data into an rlp list
    // @dev data must be rlp encoded before using this function
    // @param data_len The lenght of the bytes to copy from
    // @param data The pointer to the first byte in the array to copy from
    // @param rlp The pointer receiving the rlp encoded list
    // @return rlp_len The length of the encoded list in bytes
    func encode_rlp_list{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(data_len: felt, data: felt*, rlp: felt*) -> (rlp_len: felt) {
        alloc_locals;
        let is_le_55 = is_le(data_len, 55);
        if (is_le_55 != FALSE) {
            assert rlp[0] = 0xc0 + data_len;
            Helpers.fill_array(data_len, data, rlp + 1);
            return (rlp_len=data_len + 1);
        } else {
            let (byte_len) = Helpers.bytes_len(data_len);
            assert rlp[0] = 0xf7 + byte_len;
            let (local rs: felt*) = alloc();
            let (rs_len) = Helpers.to_base_16(0, rs, data_len);
            let (local bytes: felt*) = alloc();
            Helpers.to_bytes(bytes, rs_len, rs);
            Helpers.fill_array(byte_len, bytes, rlp + 1);
            Helpers.fill_array(data_len, data, rlp + 1 + byte_len);
            return (rlp_len=data_len + 1);
        }
    }
}
