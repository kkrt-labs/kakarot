// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import assert_lt

// Internal dependencies
from kakarot.model import model

// @title Memory related functions.
// @notice This file contains functions related to the memory.
// @dev The memory is a region that only exists during the smart contract execution, and is accessed with a byte offset.
// @dev  While all the 32-byte address space is available and initialized to 0, the size is counted with the highest address that was accessed.
// @dev It is generally read and written with `MLOAD` and `MSTORE` instructions, but is also used by other instructions like `CREATE` or `EXTCODECOPY`.
// @author @abdelhamidbakhta
// @custom:namespace Memory
// @custom:model model.Memory
namespace Memory {
    const element_size = Uint256.SIZE;

    // @notice Initialize the memory.
    // @return The pointer to the memory.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> model.Memory* {
        alloc_locals;
        let (elements: Uint256*) = alloc();
        return new model.Memory(elements=elements, raw_len=0);
    }

    // @notice Returns the len of the memory.
    // @dev The len is counted with the highest address that was accessed.
    // @param self - The pointer to the memory.
    // @return The len of the memory.
    func len{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*) -> felt {
        let actual_len = self.raw_len / element_size;
        return actual_len;
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
        let offset = offset * element_size;
        assert [self.elements + offset] = element;
        let is_size_too_small = is_le(self.raw_len, offset);
        local new_raw_len: felt;
        if (is_size_too_small == 1) {
            assert new_raw_len = offset + element_size;
        } else {
            new_raw_len = self.raw_len;
        }
        // TODO: update size if offset > current size.
        return new model.Memory(elements=self.elements, raw_len=new_raw_len);
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
            assert_lt(offset, len(self));
        }
        let element = self.elements[offset];
        return element;
    }

    // @notice Print the memory.
    // @param self - The pointer to the memory.
    func dump{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Memory*) {
        let memory_len = Memory.len(self);
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
        let element = Memory.load(self, memory_index);
        %{
            import logging
            element_str = cairo_uint256_to_str(ids.element)
            logging.info(f"{ids.memory_index} - {element_str}")
        %}
        return ();
    }
}
