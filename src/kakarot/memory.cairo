// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.math import assert_lt, split_int, unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers

// @title Memory related functions.
// @notice This file contains functions related to the memory.
// @dev The memory is a region that only exists during the smart contract execution, and is accessed with a byte offset.
// @dev  While all the 32-byte address space is available and initialized to 0, the size is counted with the highest address that was accessed.
// @dev It is generally read and written with `MLOAD` and `MSTORE` instructions, but is also used by other instructions like `CREATE` or `EXTCODECOPY`.
// @author @abdelhamidbakhta
// @custom:namespace Memory
// @custom:model model.Memory
namespace Memory {
    // @notice Initialize the memory.
    // @return The pointer to the memory.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> model.Memory* {
        alloc_locals;
        let (bytes: felt*) = alloc();
        return new model.Memory(bytes=bytes, bytes_len=0);
    }

    // @notice Store an element into the memory.
    // @param self - The pointer to the memory.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the memory.
    func store{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, element: Uint256, offset: felt) -> model.Memory* {
        alloc_locals;
        let (new_memory: felt*) = alloc();
        if (self.bytes_len == 0) {
            Helpers.fill_zeros(fill_with=offset, arr=new_memory);
        }
        let is_offset_greater_than_length = is_le_felt(self.bytes_len, offset);
        local max_copy: felt;
        if (is_offset_greater_than_length == 1) {
            Helpers.fill_zeros(fill_with=offset - self.bytes_len, arr=new_memory + self.bytes_len);
            max_copy = self.bytes_len;
        } else {
            max_copy = offset;
        }
        if (self.bytes_len != 0) {
            memcpy(dst=new_memory, src=self.bytes, len=max_copy);
        }

        split_int(
            value=element.high,
            n=16,
            base=2 ** 8,
            bound=2 ** 128,
            output=self.bytes + self.bytes_len + 16,
        );
        split_int(
            value=element.low, n=16, base=2 ** 8, bound=2 ** 128, output=self.bytes + self.bytes_len
        );
        Helpers.reverse(
            old_arr_len=32,
            old_arr=self.bytes + self.bytes_len,
            new_arr_len=32,
            new_arr=new_memory + offset,
        );

        let is_memory_growing = is_le_felt(self.bytes_len, offset + 32);
        local new_bytes_len: felt;
        if (is_memory_growing == 1) {
            new_bytes_len = offset + 32;
        } else {
            memcpy(
                dst=new_memory + offset + 32,
                src=self.bytes + offset + 32,
                len=self.bytes_len - (offset),
            );
            new_bytes_len = self.bytes_len;
        }

        return new model.Memory(bytes=new_memory, bytes_len=new_bytes_len);
    }

    // @notice MSTORE8 - Store a byte into the memory.
    // @param self - The pointer to the memory.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the memory.
    func store8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, element: felt, offset: felt) -> model.Memory* {
        alloc_locals;
        let (new_memory: felt*) = alloc();
        if (self.bytes_len == 0) {
            Helpers.fill_zeros(fill_with=offset, arr=new_memory);
        }

        let is_offset_greater_than_length = is_le_felt(self.bytes_len, offset);
        local max_copy: felt;

        assert [new_memory + offset] = element;

        let (quotient, remainder) = uint256_unsigned_div_rem(Uint256(offset, 0), Uint256(256, 0));

        local diff = 32 - remainder.low;

        if (is_offset_greater_than_length == 1) {
            Helpers.fill_zeros(fill_with=offset - self.bytes_len, arr=new_memory + self.bytes_len);
            // Fill the unused bytes into 0
            Helpers.fill_zeros(fill_with=diff, arr=new_memory + offset + 1);
            max_copy = self.bytes_len;
        } else {
            max_copy = offset;
        }

        if (self.bytes_len != 0) {
            memcpy(dst=new_memory, src=self.bytes, len=max_copy);
        }

        let is_memory_growing = is_le_felt(self.bytes_len, offset);
        local new_bytes_len: felt;
        if (is_memory_growing == 1) {
            new_bytes_len = offset + diff;
        } else {
            memcpy(
                dst=new_memory + offset + 1, src=self.bytes + offset, len=self.bytes_len - offset
            );
            new_bytes_len = self.bytes_len;
        }

        return new model.Memory(bytes=new_memory, bytes_len=new_bytes_len);
    }

    // @notice Load an element from the memory.
    // @param self - The pointer to the memory.
    // @param offset - The offset to load the element from.
    // @return The new pointer to the memory.
    // @return The loaded element.
    func load{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, offset: felt) -> Uint256 {
        alloc_locals;
        with_attr error_message("Kakarot: MemoryOverflow") {
            let res: Uint256 = Helpers.felt_as_byte_to_uint256(self.bytes + offset);
        }
        return res;
    }

    // @notice Print the memory.
    // @param self - The pointer to the memory.
    func dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*) {
        %{
            import logging
            i = 0
            res = ""
            for i in range(ids.self.bytes_len):
                res += " " + str(memory.get(ids.self.bytes + i))
                i += i
            logging.info("*************MEMORY*****************")
            logging.info(res)
            logging.info("************************************")
        %}
        return ();
    }
}
