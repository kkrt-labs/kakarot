// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt_felt
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.constants import Constants
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
    const element_size = Uint256.SIZE;

    // @notice Initialize the memory.
    // @return The pointer to the memory.
    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> model.Memory* {
        alloc_locals;
        let (elements: Uint256*) = alloc();
        return new model.Memory(elements=elements, size=0);
    }

    // @notice Returns the size of the memory.
    // @dev The size is counted with the highest address that was accessed.
    // @param self - The pointer to the memory.
    // @return The size of the memory.
    func size{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Memory*
    ) -> felt {
        let actual_len = self.raw_len / element_size;
        return actual_len;
    }

    // @notice Store an element into the memory.
    // @param self - The pointer to the memory.
    // @param element - The element to push.
    // @param offset - The offset to store the element at.
    // @return The new pointer to the memory.
    func store{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Memory*, element: Uint256, offset: felt
    ) -> model.Memory* {
        alloc_locals;
        let offset = offset * element_size;
        assert [self.elements + offset] = element;
        // TODO: update size if offset > current size.
        return new model.Memory(elements=self.elements, size=self.size);
    }

    // @notice Load an element from the memory.
    // @param self - The pointer to the memory.
    // @param offset - The offset to load the element from.
    // @return The new pointer to the memory.
    // @return The loaded element.
    func load{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Memory*, offset: felt
    ) -> (memory: model.Memory*, element: Uint256) {
        alloc_locals;
        // TODO: check that element exists.
        let element = self.elements[offset];
        return (memory=self, element=element);
    }

    // @notice Print the value of an element at a given memory index.
    // @param self - The pointer to the memory.
    // @param memory_index - The index of the element.
    // @custom:use_hint
    func print_element_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Memory*, memory_index: felt
    ) {
        let element = Memory.load(self, memory_index);
        %{
            element_str = cairo_uint256_to_str(ids.element)
            print(f"{ids.memory_index} - {element_str}")
        %}
        return ();
    }
}
