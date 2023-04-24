// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import DictAccess, dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.math import split_int, unsigned_div_rem, assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers

// @title Memory related functions.
// @notice This file contains functions related to the memory.
// @dev The memory is a region that only exists during the smart contract execution, and is accessed
// @dev with a byte offset.
// @dev While all the 32-byte address space is available and initialized to 0, the
// @dev size is counted with the highest address that was accessed.
// @dev It is generally read and written with `MLOAD` and `MSTORE` instructions,
// @dev but is also used by other instructions like `CREATE` or `EXTCODECOPY`.
// @dev The memory representation at model.Memory is a sequence of 128bit (16B) chunks,
// @dev stored as a dictionary from chunk_index to chunk_value.
// @dev Each chunk should be read as big endian representation of 16 bytes.
namespace Memory {
    // Summary of memory. Created upon finalization of the memory.
    struct Summary {
        bytes_len: felt,
        squashed_start: DictAccess*,
        squashed_end: DictAccess*,
    }

    // @notice Initialize the memory.
    // @return memory The pointer to the memory.
    func init() -> model.Memory* {
        alloc_locals;
        let (word_dict_start: DictAccess*) = default_dict_new(0);
        return new model.Memory(
            word_dict_start=word_dict_start, word_dict=word_dict_start, bytes_len=0
        );
    }

    // @notice Finalize the memory.
    // @return summary The pointer to the memory Summary.
    func finalize{range_check_ptr}(self: model.Memory*) -> Summary* {
        let (squashed_start, squashed_end) = default_dict_finalize(
            self.word_dict_start, self.word_dict, 0
        );
        return new Summary(
            bytes_len=self.bytes_len, squashed_start=squashed_start, squashed_end=squashed_end
        );
    }

    // @notice Store an element into the memory.
    // @param self The pointer to the memory.
    // @param element The element to push.
    // @param offset The offset to store the element at.
    // @return memory The new pointer to the memory.
    func store{range_check_ptr}(
        self: model.Memory*, element: Uint256, offset: felt
    ) -> model.Memory* {
        let word_dict = self.word_dict;

        // Compute new bytes_len.
        let new_min_bytes_len = Helpers.ceil_bytes_len_to_next_32_bytes_word(offset + 32);

        let fits = is_le(new_min_bytes_len, self.bytes_len);
        if (fits == FALSE) {
            tempvar new_bytes_len = new_min_bytes_len;
        } else {
            tempvar new_bytes_len = self.bytes_len;
        }

        // Check alignment of offset to 16B chunks.
        let (chunk_index, offset_in_chunk) = unsigned_div_rem(offset, 16);

        if (offset_in_chunk == 0) {
            // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it. Note that no locals were allocated at all.
            dict_write{dict_ptr=word_dict}(chunk_index, element.high);
            dict_write{dict_ptr=word_dict}(chunk_index + 1, element.low);
            return (
                new model.Memory(
                    word_dict_start=self.word_dict_start,
                    word_dict=word_dict,
                    bytes_len=new_bytes_len,
                )
            );
        }

        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        // ^---^
        //   |-- mask = 256 ** offset_in_chunk

        // Compute mask.
        tempvar mask = Helpers.pow256_rev(offset_in_chunk);
        let mask_c = 2 ** 128 / mask;

        // Split the 2 input 16B chunks at offset_in_chunk.
        let (el_hh, el_hl) = unsigned_div_rem(element.high, mask_c);
        let (el_lh, el_ll) = unsigned_div_rem(element.low, mask_c);

        // Read the words at chunk_index, chunk_index + 2.
        let (w0) = dict_read{dict_ptr=word_dict}(chunk_index);
        let (w2) = dict_read{dict_ptr=word_dict}(chunk_index + 2);

        // Compute the new words.
        let (w0_h, _) = unsigned_div_rem(w0, mask);
        let (_, w2_l) = unsigned_div_rem(w2, mask);
        let new_w0 = w0_h * mask + el_hh;
        let new_w1 = el_hl * mask + el_lh;
        let new_w2 = el_ll * mask + w2_l;

        // Write new words.
        dict_write{dict_ptr=word_dict}(chunk_index, new_w0);
        dict_write{dict_ptr=word_dict}(chunk_index + 1, new_w1);
        dict_write{dict_ptr=word_dict}(chunk_index + 2, new_w2);
        return (
            new model.Memory(
                word_dict_start=self.word_dict_start, word_dict=word_dict, bytes_len=new_bytes_len
            )
        );
    }

    // @notice Store N bytes into the memory.
    // @param self The pointer to the memory.
    // @param element_len byte length of the array to be saved on memory.
    // @param element pointer to the array that will be saved on memory.
    // @param offset The offset to store the element at.
    // @return memory The new pointer to the memory.
    func store_n{range_check_ptr}(
        self: model.Memory*, element_len: felt, element: felt*, offset: felt
    ) -> model.Memory* {
        alloc_locals;
        if (element_len == 0) {
            return self;
        }

        let word_dict = self.word_dict;

        // Compute new bytes_len.
        let new_min_bytes_len = Helpers.ceil_bytes_len_to_next_32_bytes_word(offset + element_len);

        let fits = is_le(new_min_bytes_len, self.bytes_len);
        local new_bytes_len;
        if (fits == FALSE) {
            new_bytes_len = new_min_bytes_len;
        } else {
            new_bytes_len = self.bytes_len;
        }

        // Check alignment of offset to 16B chunks.
        let (chunk_index_i, offset_in_chunk_i) = unsigned_div_rem(offset, 16);
        let (chunk_index_f, offset_in_chunk_f) = unsigned_div_rem(offset + element_len - 1, 16);
        tempvar offset_in_chunk_f = offset_in_chunk_f + 1;
        let mask_i = Helpers.pow256_rev(offset_in_chunk_i);
        let mask_f = Helpers.pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if (chunk_index_i == chunk_index_f) {
            let (w) = dict_read{dict_ptr=word_dict}(chunk_index_i);

            let (w_h, w_l) = Helpers.div_rem(w, mask_i);
            let (_, w_ll) = Helpers.div_rem(w_l, mask_f);
            let x = Helpers.load_word(element_len, element);
            let new_w = w_h * mask_i + x * mask_f + w_ll;
            dict_write{dict_ptr=word_dict}(chunk_index_i, new_w);
            return (
                new model.Memory(
                    word_dict_start=self.word_dict_start,
                    word_dict=word_dict,
                    bytes_len=new_bytes_len,
                )
            );
        }

        // Otherwise.
        // Fill first word.
        let (w_i) = dict_read{dict_ptr=word_dict}(chunk_index_i);
        let (w_i_h, _) = Helpers.div_rem(w_i, mask_i);
        let x_i = Helpers.load_word(16 - offset_in_chunk_i, element);
        dict_write{dict_ptr=word_dict}(chunk_index_i, w_i_h * mask_i + x_i);

        // Fill last word.
        let (w_f) = dict_read{dict_ptr=word_dict}(chunk_index_f);
        let (_, w_f_l) = Helpers.div_rem(w_f, mask_f);
        let x_f = Helpers.load_word(offset_in_chunk_f, element + element_len - offset_in_chunk_f);
        dict_write{dict_ptr=word_dict}(chunk_index_f, x_f * mask_f + w_f_l);

        // Write blocks.
        let (word_dict) = store_aligned_words(
            word_dict, chunk_index_i + 1, chunk_index_f, element + 16 - offset_in_chunk_i
        );

        return (
            new model.Memory(
                word_dict_start=self.word_dict_start, word_dict=word_dict, bytes_len=new_bytes_len
            )
        );
    }

    func store_aligned_words{range_check_ptr}(
        word_dict: DictAccess*, chunk_index: felt, chunk_index_f: felt, element: felt*
    ) -> (word_dict: DictAccess*) {
        if (chunk_index == chunk_index_f) {
            return (word_dict=word_dict);
        }
        let current = (
            element[0] * 256 ** 15 +
            element[1] * 256 ** 14 +
            element[2] * 256 ** 13 +
            element[3] * 256 ** 12 +
            element[4] * 256 ** 11 +
            element[5] * 256 ** 10 +
            element[6] * 256 ** 9 +
            element[7] * 256 ** 8 +
            element[8] * 256 ** 7 +
            element[9] * 256 ** 6 +
            element[10] * 256 ** 5 +
            element[11] * 256 ** 4 +
            element[12] * 256 ** 3 +
            element[13] * 256 ** 2 +
            element[14] * 256 ** 1 +
            element[15] * 256 ** 0
        );
        dict_write{dict_ptr=word_dict}(chunk_index, current);
        return store_aligned_words(
            word_dict=word_dict,
            chunk_index=chunk_index + 1,
            chunk_index_f=chunk_index_f,
            element=&element[16],
        );
    }

    // @notice Load an element from the memory.
    // @param self The pointer to the memory.
    // @param offset The offset to load the element from.
    // @param n The number of bytes to load from memory.
    // @return memory The new pointer to the memory.
    // @return loaded_element The loaded element.
    func _load{range_check_ptr}(self: model.Memory*, offset: felt) -> (model.Memory*, Uint256) {
        let word_dict = self.word_dict;

        // Check alignment of offset to 16B chunks.
        let (chunk_index, offset_in_chunk) = unsigned_div_rem(offset, 16);

        if (offset_in_chunk == 0) {
            // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it. Note that no locals were allocated at all.
            let (el_h) = dict_read{dict_ptr=word_dict}(chunk_index);
            let (el_l) = dict_read{dict_ptr=word_dict}(chunk_index + 1);
            return (
                new model.Memory(
                    word_dict_start=self.word_dict_start,
                    word_dict=word_dict,
                    bytes_len=self.bytes_len,
                ),
                Uint256(low=el_l, high=el_h),
            );
        }

        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        //      ^---^
        //         |-- mask = 256 ** offset_in_chunk

        // Compute mask.
        tempvar mask = Helpers.pow256_rev(offset_in_chunk);
        tempvar mask_c = 2 ** 128 / mask;

        // Read words.
        let (w0) = dict_read{dict_ptr=word_dict}(chunk_index);
        let (w1) = dict_read{dict_ptr=word_dict}(chunk_index + 1);
        let (w2) = dict_read{dict_ptr=word_dict}(chunk_index + 2);

        // Compute element words.
        let (_, w0_l) = unsigned_div_rem(w0, mask);
        let (w1_h, w1_l) = unsigned_div_rem(w1, mask);
        let (w2_h, _) = unsigned_div_rem(w2, mask);
        let el_h = w0_l * mask_c + w1_h;
        let el_l = w1_l * mask_c + w2_h;
        return (
            new model.Memory(
                word_dict_start=self.word_dict_start, word_dict=word_dict, bytes_len=self.bytes_len
            ),
            Uint256(low=el_l, high=el_h),
        );
    }

    // @notice Load N bytes from the memory.
    // @param self The pointer to the memory.
    // @param element_len byte length of the output array.
    // @param element pointer to the output array.
    // @param offset The memory offset to load from.
    // @return memory The new pointer to the memory.
    func _load_n{range_check_ptr}(
        self: model.Memory*, element_len: felt, element: felt*, offset: felt
    ) -> model.Memory* {
        alloc_locals;
        if (element_len == 0) {
            return self;
        }

        let word_dict = self.word_dict;

        // Check alignment of offset to 16B chunks.
        let (chunk_index_i, offset_in_chunk_i) = unsigned_div_rem(offset, 16);
        let (chunk_index_f, offset_in_chunk_f) = unsigned_div_rem(offset + element_len - 1, 16);
        tempvar offset_in_chunk_f = offset_in_chunk_f + 1;
        let mask_i = Helpers.pow256_rev(offset_in_chunk_i);
        let mask_f = Helpers.pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if (chunk_index_i == chunk_index_f) {
            let (w) = dict_read{dict_ptr=word_dict}(chunk_index_i);
            let (_, w_l) = Helpers.div_rem(w, mask_i);
            let (w_lh, _) = Helpers.div_rem(w_l, mask_f);
            Helpers.split_word(w_lh, element_len, element);
            return (
                new model.Memory(
                    word_dict_start=self.word_dict_start,
                    word_dict=word_dict,
                    bytes_len=self.bytes_len,
                )
            );
        }

        // Otherwise.
        // Get first word.
        let (w_i) = dict_read{dict_ptr=word_dict}(chunk_index_i);
        let (_, w_i_l) = Helpers.div_rem(w_i, mask_i);
        Helpers.split_word(w_i_l, 16 - offset_in_chunk_i, element);

        // Get last word.
        let (w_f) = dict_read{dict_ptr=word_dict}(chunk_index_f);
        let (w_f_h, _) = Helpers.div_rem(w_f, mask_f);
        Helpers.split_word(w_f_h, offset_in_chunk_f, element + element_len - offset_in_chunk_f);

        // Get blocks.
        let (word_dict) = load_aligned_words(
            word_dict, chunk_index_i + 1, chunk_index_f, element + 16 - offset_in_chunk_i
        );

        return (
            new model.Memory(
                word_dict_start=self.word_dict_start, word_dict=word_dict, bytes_len=self.bytes_len
            )
        );
    }

    func load_aligned_words{range_check_ptr}(
        word_dict: DictAccess*, chunk_index: felt, chunk_index_f: felt, element: felt*
    ) -> (word_dict: DictAccess*) {
        if (chunk_index == chunk_index_f) {
            return (word_dict=word_dict);
        }
        let original_word_dict = word_dict;
        let (value) = dict_read{dict_ptr=word_dict}(chunk_index);
        let word_dict = original_word_dict + 3;
        Helpers.split_word_128(value, element);
        return load_aligned_words(
            word_dict=word_dict,
            chunk_index=chunk_index + 1,
            chunk_index_f=chunk_index_f,
            element=&element[16],
        );
    }

    // @notice Expend the memory with length bytes
    // @param self The pointer to the memory.
    // @param length The number of bytes to add.
    // @return new_memory The new pointer to the memory.
    // @return cost The gas cost of this expansion.
    func expand{range_check_ptr}(self: model.Memory*, length: felt) -> (
        new_memory: model.Memory*, cost: felt
    ) {
        let (last_memory_size_word, _) = unsigned_div_rem(value=self.bytes_len + 31, div=32);
        let (last_memory_cost, _) = unsigned_div_rem(
            value=last_memory_size_word * last_memory_size_word, div=512
        );
        let last_memory_cost = last_memory_cost + (3 * last_memory_size_word);

        tempvar new_bytes_len = self.bytes_len + length;
        let (new_memory_size_word, _) = unsigned_div_rem(value=new_bytes_len + 31, div=32);
        let (new_memory_cost, _) = unsigned_div_rem(
            value=new_memory_size_word * new_memory_size_word, div=512
        );
        let new_memory_cost = new_memory_cost + (3 * new_memory_size_word);

        let cost = new_memory_cost - last_memory_cost;

        return (
            new model.Memory(
                word_dict_start=self.word_dict_start,
                word_dict=self.word_dict,
                bytes_len=new_bytes_len,
            ),
            cost,
        );
    }

    // @notice Ensure that the memory as at least length bytes. Expand if necessary.
    // @param self The pointer to the memory.
    // @param offset The number of bytes to add.
    // @return new_memory The new pointer to the memory.
    // @return cost The gas cost of this expansion.
    func ensure_length{range_check_ptr}(self: model.Memory*, length: felt) -> (
        new_memory: model.Memory*, cost: felt
    ) {
        let is_memory_expanding = is_le(self.bytes_len + 1, length);
        if (is_memory_expanding != 0) {
            let (new_memory, cost) = Memory.expand(self=self, length=length - self.bytes_len);
            return (new_memory, cost);
        }
        return (new_memory=self, cost=0);
    }

    // @notice Expand memory if necessary then load 32 bytes from it at given offset.
    // @param self The pointer to the memory.
    // @param offset The number of bytes to add.
    // @return new_memory The new pointer to the memory.
    // @return loaded_element The loaded Uint256 from memory.
    // @return gas_cost The gas cost of this expansion.
    func load{range_check_ptr}(self: model.Memory*, offset: felt) -> (
        new_memory: model.Memory*, loaded_element: Uint256, gas_cost: felt
    ) {
        alloc_locals;
        let (new_memory, gas_cost) = ensure_length(self=self, length=32 + offset);
        let (new_memory, loaded_element) = _load(self=new_memory, offset=offset);
        return (new_memory, loaded_element, gas_cost);
    }

    // @notice Expand memory if necessary then load n bytes from it at given offset.
    // @param self The pointer to the memory.
    // @param element_len The number of bytes to load.
    // @param element The pointer to the filled array.
    // @param offset The number of bytes to add.
    // @return new_memory The new pointer to the memory.
    // @return gas_cost The gas cost of this expansion.
    func load_n{range_check_ptr}(
        self: model.Memory*, element_len: felt, element: felt*, offset: felt
    ) -> (new_memory: model.Memory*, gas_cost: felt) {
        alloc_locals;
        let (new_memory, gas_cost) = ensure_length(self=self, length=element_len + offset);
        let new_memory = _load_n(new_memory, element_len, element, offset=offset);
        return (new_memory, gas_cost);
    }
}
