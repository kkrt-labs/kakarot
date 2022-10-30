// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le_felt, is_le
from starkware.cairo.common.math import assert_lt, split_int, unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.bool import TRUE

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
            Helpers.fill(arr=new_memory, value=0, length=offset);
        }
        let is_offset_greater_than_length = is_le_felt(self.bytes_len, offset);
        local max_copy: felt;
        if (is_offset_greater_than_length == 1) {
            Helpers.fill(arr=new_memory + self.bytes_len, value=0, length=offset - self.bytes_len);
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

    // @notice store_n - Store N bytes into the memory.
    // @param self - The pointer to the memory.
    // @param element_len - byte length of the array to be saved on memory.
    // @param element - pointer to the array that will be saved on memory.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the memory.
    func store_n{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, element_len: felt, element: felt*, offset: felt) -> model.Memory* {
        alloc_locals;
        let (new_memory: felt*) = alloc();
        if (self.bytes_len == 0) {
            Helpers.fill(arr=new_memory, value=0, length=offset);
        }

        let is_offset_greater_than_length = is_le_felt(self.bytes_len, offset);
        local max_copy: felt;
        local total_len: felt = offset + element_len;
        tempvar max_uint256_bytes: felt = 32;

        // Add all the elements into new_memory
        Helpers.fill_array(
            fill_with=element_len, input_arr=element, output_arr=new_memory + offset
        );

        let (local quotient, local remainder) = uint256_unsigned_div_rem(
            Uint256(offset + element_len, 0), Uint256(max_uint256_bytes, 0)
        );
        local diff: felt;
        if (remainder.low == 0) {
            diff = 0;
        } else {
            diff = max_uint256_bytes - remainder.low;
        }

        if (is_offset_greater_than_length == 1) {
            Helpers.fill(arr=new_memory + self.bytes_len, value=0, length=offset - self.bytes_len);
            // Fill the unused bytes into 0
            Helpers.fill(arr=new_memory + total_len, value=0, length=diff);
            max_copy = self.bytes_len;
        } else {
            max_copy = offset;
        }

        if (self.bytes_len != 0) {
            memcpy(dst=new_memory, src=self.bytes, len=max_copy);
        }

        let is_memory_growing = is_le_felt(self.bytes_len, total_len);

        local new_bytes_len: felt;
        if (is_memory_growing == 1) {
            new_bytes_len = total_len + (diff);
        } else {
            memcpy(
                dst=new_memory + total_len,
                src=self.bytes + total_len,
                len=self.bytes_len - (total_len),
            );
            new_bytes_len = self.bytes_len;
        }
        return new model.Memory(bytes=new_memory, bytes_len=new_bytes_len);
    }

    // @notice CODECOPY - (Over)write byte array into the memory with zero padding.
    // @param self - The pointer to the memory.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the memory.
    func store_bytes{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, bytes_len: felt, bytes: felt*, offset: felt) -> model.Memory* {
        alloc_locals;
        let (new_memory: felt*) = alloc();

        // Leading block of memory
        let is_offset_greater_than_length = is_le_felt(self.bytes_len + 1, offset);
        if (is_offset_greater_than_length == 1) {
            memcpy(dst=new_memory, src=self.bytes, len=self.bytes_len);
            Helpers.fill(arr=new_memory + self.bytes_len, value=0, length=offset - self.bytes_len);
        } else {
            memcpy(dst=new_memory, src=self.bytes, len=offset);
        }

        // Copied new block of memory
        memcpy(dst=new_memory + offset, src=bytes, len=bytes_len);

        // Trailing block of memory
        let is_memory_expanded: felt = is_le_felt(self.bytes_len + 1, offset + bytes_len);
        if (is_memory_expanded == 1) {
            let (_, rem) = unsigned_div_rem(offset + bytes_len, 32);
            let is_rem_pos: felt = is_le_felt(1, rem);
            let padding_len: felt = (32 - rem) * is_rem_pos;
            Helpers.fill(arr=new_memory + offset + bytes_len, value=0, length=padding_len);
            let new_memory_len: felt = offset + bytes_len + padding_len;
            return new model.Memory(bytes=new_memory, bytes_len=new_memory_len);
        } else {
            memcpy(
                dst=new_memory + offset + bytes_len,
                src=self.bytes + offset + bytes_len,
                len=self.bytes_len - offset - bytes_len,
            );
            let new_memory_len: felt = self.bytes_len;
            return new model.Memory(bytes=new_memory, bytes_len=new_memory_len);
        }
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

        // Check if the offset + 32 > MSIZE
        let offset_out_of_bounds = is_le(self.bytes_len, offset + 32 + 1);
        if (offset_out_of_bounds == 1) {
            let (local new_memory: felt*) = alloc();
            memcpy(dst=new_memory, src=self.bytes, len=self.bytes_len);
            Helpers.fill(
                arr=new_memory + self.bytes_len, value=0, length=offset + 32 - self.bytes_len
            );
            let res: Uint256 = Helpers.bytes32_to_uint256(new_memory + offset);
            return res;
        }
        with_attr error_message("Kakarot: Memory Error") {
            let res: Uint256 = Helpers.bytes32_to_uint256(self.bytes + offset);
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

    // @notice Expend the memory with length bytes
    // @param self - The pointer to the memory.
    // @param length - The number of bytes to add.
    // @return The new pointer to the memory.
    // @return The gas cost of this expansion.
    func expand{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, length: felt) -> (new_memory: model.Memory*, cost: felt) {
        Helpers.fill(self.bytes + self.bytes_len, value=0, length=length);
        let (last_memory_size_word, _) = unsigned_div_rem(self.bytes_len + 31, 32);
        let (last_memory_cost, _) = unsigned_div_rem(
            last_memory_size_word * last_memory_size_word, 512
        );
        let last_memory_cost = last_memory_cost + (3 * last_memory_size_word);

        let (new_memory_size_word, _) = unsigned_div_rem(self.bytes_len + length + 31, 32);
        let (new_memory_cost, _) = unsigned_div_rem(
            new_memory_size_word * new_memory_size_word, 512
        );
        let new_memory_cost = new_memory_cost + (3 * new_memory_size_word);

        let cost = new_memory_cost - last_memory_cost;

        return (new model.Memory(bytes=self.bytes, bytes_len=self.bytes_len + length), cost);
    }

    // @notice Insure that the memory as at least length bytes. Expand if necessary.
    // @param self - The pointer to the memory.
    // @param offset - The number of bytes to add.
    // @return The new pointer to the memory.
    // @return The gas cost of this expansion.
    func insure_length{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, length: felt) -> (new_memory: model.Memory*, cost: felt) {
        let is_memory_expanding = is_le_felt(self.bytes_len + 1, length);
        if (is_memory_expanding == TRUE) {
            let (new_memory, cost) = Memory.expand(self, length - self.bytes_len);
            return (new_memory, cost);
        } else {
            return (new_memory=self, cost=0);
        }
    }
}
