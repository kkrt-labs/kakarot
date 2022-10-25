// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
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
        return new model.Memory(bytes=bytes, bytes_len=0, init_offset=2**128);
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
        let (memory: felt*) = alloc();
        if (self.bytes_len != 0) {
            memcpy(dst=memory, src=self.bytes, len=offset);
        }
        split_int(
            value=element.high, n=16, base=2 ** 8, bound=2 ** 128, output=memory + offset + 16
        );
        split_int(value=element.low, n=16, base=2 ** 8, bound=2 ** 128, output=memory + offset);

        let is_offset_lower = is_le(offset, self.init_offset);

        let init_offset = self.init_offset;
        if (is_offset_lower == 1){
            init_offset = offset;
        }

        // TODO: Fill with 0 if offset > bytes_len
        let is_memory_expanded = is_le(self.bytes_len, offset + 32);
        if (is_memory_expanded == 1) {
            return new model.Memory(bytes=memory, bytes_len=offset + 32, init_offset=init_offset);
        } else {
            memcpy(
                dst=memory + offset + 32,
                src=self.bytes + offset + 32,
                len=self.bytes_len - 32 - offset,
            );
            return new model.Memory(bytes=memory, bytes_len=self.bytes_len,  init_offset=init_offset);
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
        with_attr error_message("Kakarot: MemoryUnderflow") {
            assert_lt(offset, self.bytes_len);
        }
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
        let (memory_len, _rem) = unsigned_div_rem(self.bytes_len, 32);
        if (memory_len == 0) {
            return ();
        }
        let last_index = memory_len - 1;
        inner_dump(self, 0, last_index);
        return ();
    }

    // @notice Recursively print the memory.
    // @param self - The pointer to the memory.
    // @param memory_index - The index of the element.
    // @param last_index - The index of the last element.
    func inner_dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, memory_index: felt, last_index: felt) {
        Memory.print_element_at(self, memory_index);
        if (memory_index == last_index) {
            return ();
        }
        return inner_dump(self, memory_index + 1, last_index);
    }

    // @notice Print the value of an element at a given memory index.
    // @param self - The pointer to the memory.
    // @param memory_index - The index of the element.
    // @custom:use_hint
    func print_element_at{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*, memory_index: felt) {
        let element = Memory.load(self, memory_index * 32);
        %{
            import logging
            element_str = cairo_uint256_to_str(ids.element)
            logging.info(f"{ids.memory_index} - {element_str}")
        %}
        return ();
    }
}
