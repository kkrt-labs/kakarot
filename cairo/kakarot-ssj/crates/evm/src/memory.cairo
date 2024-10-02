use core::cmp::min;
use core::dict::{Felt252Dict, Felt252DictTrait};
use core::integer::{u32_safe_divmod};
use utils::constants::{
    POW_2_0, POW_2_8, POW_2_16, POW_2_24, POW_2_32, POW_2_40, POW_2_48, POW_2_56, POW_2_64,
    POW_2_72, POW_2_80, POW_2_88, POW_2_96, POW_2_104, POW_2_112, POW_2_120, POW_256_16
};
use utils::traits::array::ArrayExtTrait;
use utils::traits::bytes::FromBytes;
use utils::{helpers, math::Bitshift};

#[derive(Destruct, Default)]
pub struct Memory {
    items: Felt252Dict<u128>,
    bytes_len: usize,
}

pub trait MemoryTrait {
    fn new() -> Memory;
    fn size(self: @Memory) -> usize;
    fn store(ref self: Memory, element: u256, offset: usize);
    fn store_byte(ref self: Memory, value: u8, offset: usize);
    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize);
    fn store_padded_segment(ref self: Memory, offset: usize, length: usize, source: Span<u8>);
    fn ensure_length(ref self: Memory, length: usize);
    fn load(ref self: Memory, offset: usize) -> u256;
    fn load_n(ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize);
    fn copy(ref self: Memory, size: usize, source_offset: usize, dest_offset: usize);
}

impl MemoryImpl of MemoryTrait {
    /// Initializes a new `Memory` instance.
    #[inline(always)]
    fn new() -> Memory {
        Memory { items: Default::default(), bytes_len: Default::default() }
    }
    /// Returns the size of the memory.
    #[inline(always)]
    fn size(self: @Memory) -> usize {
        *self.bytes_len
    }

    /// Stores a 32-bytes element into the memory.
    ///
    /// If the offset is aligned with the 16-bytes words in memory, the element is stored directly.
    /// Otherwise, the element is split and stored in multiple words.
    #[inline(always)]
    fn store(ref self: Memory, element: u256, offset: usize) {
        let nonzero_16: NonZero<u32> = 16_u32.try_into().unwrap();

        // Check alignment of offset to bytes16 chunks
        let (chunk_index, offset_in_chunk) = u32_safe_divmod(offset, nonzero_16);

        if offset_in_chunk == 0 {
            // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it.
            self.items.store_u256(element, chunk_index);
            return ();
        }

        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        // ^---^
        // |-- mask = 256 ** offset_in_chunk

        self.store_element(element, chunk_index, offset_in_chunk);
    }


    /// Stores a single byte into memory at a specified offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the byte in.
    /// * `value` - The byte value to store in memory.
    /// * `offset` - The offset within memory to store the byte at.
    #[inline(always)]
    fn store_byte(ref self: Memory, value: u8, offset: usize) {
        let nonzero_16: NonZero<u32> = 16_u32.try_into().unwrap();

        // Get offset's memory word index and left-based offset of byte in word.
        let (chunk_index, left_offset) = u32_safe_divmod(offset, nonzero_16);

        // As the memory words are in big-endian order, we need to convert our left-based offset
        // to a right-based one.
        let right_offset = 15 - left_offset;
        let mask: u128 = 0xFF * helpers::pow2(right_offset.into() * 8);

        // First erase byte value at offset, then set the new value using bitwise ops
        let word: u128 = self.items.get(chunk_index.into());
        let new_word = (word & ~mask) | (value.into().shl(right_offset * 8));
        self.items.insert(chunk_index.into(), new_word);
    }


    /// Stores a span of N bytes into memory at a specified offset.
    ///
    /// This function checks the alignment of the offset to 16-byte chunks, and handles the special
    /// case where the bytes to be stored are within the same word in memory using the
    /// `store_bytes_in_single_chunk` function. If the bytes span multiple words, the function
    /// stores the first word using the `store_first_word` function, the aligned words using the
    /// `store_aligned_words` function, and the last word using the `store_last_word` function.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the bytes in.
    /// * `elements` - A span of bytes to store in memory.
    /// * `offset` - The offset within memory to store the bytes at.
    #[inline(always)]
    fn store_n(ref self: Memory, elements: Span<u8>, offset: usize) {
        if elements.len() == 0 {
            return;
        }

        let nonzero_16: NonZero<u32> = 16_u32.try_into().unwrap();

        // Compute the offset inside the Memory, given its active segment, following the formula:
        // index = offset + self.active_segment * 125000

        // Check alignment of offset to bytes16 chunks.
        let (initial_chunk, offset_in_chunk_i) = u32_safe_divmod(offset, nonzero_16);
        let (final_chunk, mut offset_in_chunk_f) = u32_safe_divmod(
            offset + elements.len() - 1, nonzero_16
        );
        offset_in_chunk_f += 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: the bytes are stored within the same word.
        if initial_chunk == final_chunk {
            self.store_bytes_in_single_chunk(initial_chunk, mask_i, mask_f, elements);
            return ();
        }

        // Otherwise, fill first word.
        self.store_first_word(initial_chunk, offset_in_chunk_i, mask_i, elements);

        // Store aligned bytes in [initial_chunk + 1, final_chunk - 1].
        // If initial_chunk + 1 == final_chunk, this will store nothing.
        if initial_chunk + 1 != final_chunk {
            let aligned_bytes = elements
                .slice(
                    16 - offset_in_chunk_i,
                    elements.len() - (16 - offset_in_chunk_i) - offset_in_chunk_f,
                );
            self.store_aligned_words(initial_chunk + 1, aligned_bytes);
        }

        let final_bytes = elements.slice(elements.len() - offset_in_chunk_f, offset_in_chunk_f);
        self.store_last_word(final_chunk, offset_in_chunk_f, mask_f, final_bytes);
    }

    /// Stores a span of N bytes into memory at a specified offset with padded with 0s to match the
    /// size parameter.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the bytes in.
    /// * `offset` - The offset within memory to store the bytes at.
    /// * `length` - The length of bytes to store in memory.
    /// * `source` - A span of bytes to store in memory.
    #[inline(always)]
    fn store_padded_segment(ref self: Memory, offset: usize, length: usize, source: Span<u8>) {
        if length == 0 {
            return;
        }

        // For performance reasons, we don't add the zeros directly to the source, which would
        // generate an implicit copy, which might be expensive if the source is big.
        // Instead, we'll copy the source into memory, then create a new span containing the zeros.
        // TODO: optimize this with a specific function
        let mut slice_size = min(source.len(), length);

        let data_to_copy: Span<u8> = source.slice(0, slice_size);
        self.store_n(data_to_copy, offset);
        // For out of bound bytes, 0s will be copied.
        if (length > source.len()) {
            let mut out_of_bounds_bytes: Array<u8> = ArrayTrait::new();
            out_of_bounds_bytes.append_n(0, length - source.len());

            self.store_n(out_of_bounds_bytes.span(), offset + slice_size);
        }
    }

    /// Ensures that the memory is at least `length` bytes long. Expands if necessary.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance.
    /// * `length` - The desired minimum length of the memory.
    #[inline(always)]
    fn ensure_length(ref self: Memory, length: usize) {
        if self.size() < length {
            self.expand(length - self.size())
        } else {
            return;
        }
    }

    /// Expands memory if necessary, then load 32 bytes from it at the given offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance.
    /// * `offset` - The offset within memory to load from.
    ///
    /// # Returns
    ///
    /// * `u256` - The loaded value.
    #[inline(always)]
    fn load(ref self: Memory, offset: usize) -> u256 {
        self.load_internal(offset)
    }

    /// Expands memory if necessary, then load elements_len bytes from the memory at given offset
    /// inside elements.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance.
    /// * `elements_len` - The number of bytes to load.
    /// * `elements` - A mutable reference to the array to store the loaded bytes.
    /// * `offset` - The offset within memory to load from.
    #[inline(always)]
    fn load_n(ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize) {
        self.load_n_internal(elements_len, ref elements, offset);
    }

    /// Copies a segment of memory from the source offset to the destination offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance.
    /// * `size` - The number of bytes to copy.
    /// * `source_offset` - The offset to copy from.
    /// * `dest_offset` - The offset to copy to.
    #[inline(always)]
    fn copy(ref self: Memory, size: usize, source_offset: usize, dest_offset: usize) {
        let mut data: Array<u8> = Default::default();
        self.load_n(size, ref data, source_offset);
        self.store_n(data.span(), dest_offset);
    }
}

#[generate_trait]
pub(crate) impl InternalMemoryMethods of InternalMemoryTrait {
    /// Stores a `u256` element at a specified offset within a memory chunk.
    ///
    /// It first computes the
    /// masks for the high and low parts of the element, then splits the `u256` element into high
    /// and low parts, and computes the new words to write to memory using the masks and the high
    /// and low parts of the element. Finally, it writes the new words to memory.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the element in.
    /// * `element` - The `u256` element to store in memory.
    /// * `chunk_index` - The index of the memory chunk to start storing the element in.
    /// * `offset_in_chunk` - The offset within the memory chunk to store the element at.
    #[inline(always)]
    fn store_element(ref self: Memory, element: u256, chunk_index: usize, offset_in_chunk: u32) {
        let mask: u256 = helpers::pow256_rev(offset_in_chunk);
        let mask_c: u256 = POW_256_16 / mask;

        // Split the 2 input bytes16 chunks at offset_in_chunk.
        let nonzero_mask_c: NonZero<u256> = mask_c.try_into().unwrap();
        let (el_hh, el_hl) = DivRem::div_rem(element.high.into(), nonzero_mask_c);
        let (el_lh, el_ll) = DivRem::div_rem(element.low.into(), nonzero_mask_c);

        // Read the words at chunk_index, chunk_index + 2.
        let w0: u128 = self.items.get(chunk_index.into());
        let w2: u128 = self.items.get(chunk_index.into() + 2);

        // Compute the new words
        let w0_h: u256 = (w0.into() / mask);
        let w2_l: u256 = (w2.into() / mask);

        // We can convert them back to felt252 as we know they fit in one word.
        let new_w0: u128 = (w0_h.into() * mask + el_hh).try_into().unwrap();
        let new_w1: u128 = (el_hl.into() * mask + el_lh).try_into().unwrap();
        let new_w2: u128 = (el_ll.into() * mask + w2_l).try_into().unwrap();

        // Write the new words
        self.items.insert(chunk_index.into(), new_w0);
        self.items.insert(chunk_index.into() + 1, new_w1);
        self.items.insert(chunk_index.into() + 2, new_w2);
    }

    /// Stores a span of bytes into a single memory chunk.
    ///
    /// This function computes a new word to be stored by combining the existing word with the new
    /// bytes.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the bytes in.
    /// * `initial_chunk` - The index of the initial memory chunk to store the bytes in.
    /// * `mask_i` - The mask for the high part of the word.
    /// * `mask_f` - The mask for the low part of the word.
    /// * `elements` - A span of bytes to store in memory.
    #[inline(always)]
    fn store_bytes_in_single_chunk(
        ref self: Memory, initial_chunk: usize, mask_i: u256, mask_f: u256, elements: Span<u8>
    ) {
        let word: u128 = self.items.get(initial_chunk.into());
        let nonzero_mask_i: NonZero<u256> = mask_i.try_into().unwrap();
        let nonzero_mask_f: NonZero<u256> = mask_f.try_into().unwrap();
        let (word_high, word_low) = DivRem::div_rem(word.into(), nonzero_mask_i);
        let (_, word_low_l) = DivRem::div_rem(word_low, nonzero_mask_f);
        let bytes_as_word: u128 = elements
            .slice(0, elements.len())
            .from_be_bytes_partial()
            .expect('Failed to parse word_low');
        let new_w: u128 = (word_high * mask_i + bytes_as_word.into() * mask_f + word_low_l)
            .try_into()
            .unwrap();
        self.items.insert(initial_chunk.into(), new_w);
    }

    /// Stores a sequence of bytes into memory in chunks of 16 bytes each.
    ///
    /// It combines each byte in the span into a single 16-byte value in big-endian order,
    /// and stores this value in memory. The function then updates
    /// the chunk index and slices the byte span to the next 16 bytes until all chunks have been
    /// stored.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `Memory` instance to store the bytes in.
    /// * `chunk_index` - The index of the chunk to start storing at.
    /// * `elements` - A span of bytes to store in memory.
    fn store_aligned_words(ref self: Memory, mut chunk_index: usize, mut elements: Span<u8>) {
        while let Option::Some(words) = elements.multi_pop_front::<16>() {
            let words = (*words).unbox().span();
            let current: u128 = ((*words[0]).into() * POW_2_120
                + (*words[1]).into() * POW_2_112
                + (*words[2]).into() * POW_2_104
                + (*words[3]).into() * POW_2_96
                + (*words[4]).into() * POW_2_88
                + (*words[5]).into() * POW_2_80
                + (*words[6]).into() * POW_2_72
                + (*words[7]).into() * POW_2_64
                + (*words[8]).into() * POW_2_56
                + (*words[9]).into() * POW_2_48
                + (*words[10]).into() * POW_2_40
                + (*words[11]).into() * POW_2_32
                + (*words[12]).into() * POW_2_24
                + (*words[13]).into() * POW_2_16
                + (*words[14]).into() * POW_2_8
                + (*words[15]).into() * POW_2_0);

            self.items.insert(chunk_index.into(), current);
            chunk_index += 1;
        }
    }

    /// Retrieves aligned values from the memory structure, converts them back into a bytes array,
    /// and appends them to the `elements` array.
    ///
    /// It iterates
    /// over the chunks between the first and last chunk indices, retrieves the `u128` values from
    /// the memory chunk, and splits them into big-endian byte arrays and concatenates using the
    /// `split_word_128` function.
    /// The results are concatenated to the `elements` array.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the values from.
    /// * `chunk_index` - The index of the first chunk to load from.
    /// * `final_chunk` - The index of the last chunk to load from.
    /// * `elements` - A reference to the byte array to append the loaded bytes to.
    fn load_aligned_words(
        ref self: Memory, mut chunk_index: usize, final_chunk: usize, ref elements: Array<u8>
    ) {
        for i in chunk_index
            ..final_chunk {
                let value = self.items.get(i.into());
                // Pushes 16 items to `elements`
                helpers::split_word_128(value.into(), ref elements);
            };
    }

    /// Loads a `u256` element from the memory chunk at a specified offset.
    ///
    /// If the offset is aligned with the memory words, the function returns the `u256` element at
    /// the specified offset directly from the memory chunk. If the offset is misaligned, the
    /// function computes the masks for the high and low parts of the first and last words of the
    /// `u256` element, reads the words at the specified offset and the next two offsets, and
    /// computes the high and low parts of the `u256` element using the masks and the read words.
    /// The resulting `u256` element is then returned.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the element from.
    /// * `offset` - The offset within the memory chunk to load the element from.
    ///
    /// # Returns
    ///
    /// The `u256` element at the specified offset in the memory chunk.
    #[inline(always)]
    fn load_internal(ref self: Memory, offset: usize) -> u256 {
        // Compute the offset inside the dict, given its active segment, following the formula:
        // index = offset + self.active_segment * 125000
        let nonzero_16: NonZero<u32> = 16_u32.try_into().unwrap();
        let (chunk_index, offset_in_chunk) = u32_safe_divmod(offset, nonzero_16);

        if offset_in_chunk == 0 {
            // Offset is aligned. This is the simplest and most efficient case,
            // so we optimize for it. Note that no locals were allocated at all.
            return self.items.read_u256(chunk_index);
        }

        // Offset is misaligned.
        // |   W0   |   W1   |   w2   |
        //     |  EL_H  |  EL_L  |
        //      ^---^
        //         |-- mask = 256 ** offset_in_chunk

        // Compute mask.

        let mask: u256 = helpers::pow256_rev(offset_in_chunk);
        let mask_c: u256 = POW_256_16 / mask;

        // Read the words at chunk_index, +1, +2.
        let w0: u128 = self.items.get(chunk_index.into());
        let w1: u128 = self.items.get(chunk_index.into() + 1);
        let w2: u128 = self.items.get(chunk_index.into() + 2);

        // Compute element words
        let w0_l: u256 = w0.into() % mask;
        let nonzero_mask: NonZero<u256> = mask.try_into().unwrap();
        let (w1_h, w1_l): (u256, u256) = DivRem::div_rem(w1.into(), nonzero_mask);
        let w2_h: u256 = w2.into() / mask;
        let el_h: u128 = (w0_l * mask_c + w1_h).try_into().unwrap();
        let el_l: u128 = (w1_l * mask_c + w2_h).try_into().unwrap();

        u256 { low: el_l, high: el_h }
    }

    /// Loads a span of bytes from the memory chunk at a specified offset.
    ///
    /// This function loads the n bytes from the memory chunks, and splits the first word,
    /// the aligned words, and the last word into bytes using the masks, and stored in
    /// the parameter `elements` array.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to load the bytes from.
    /// * `elements_len` - The length of the array of bytes to load.
    /// * `elements` - A reference to the array of bytes to load.
    /// * `offset` - The chunk memory offset to load the bytes from.
    #[inline(always)]
    fn load_n_internal(
        ref self: Memory, elements_len: usize, ref elements: Array<u8>, offset: usize
    ) {
        if elements_len == 0 {
            return;
        }

        let nonzero_16: NonZero<u32> = 16_u32.try_into().unwrap();

        // Compute the offset inside the Memory, given its active segment, following the formula:
        // index = offset + self.active_segment * 125000

        // Check alignment of offset to bytes16 chunks.
        let (initial_chunk, offset_in_chunk_i) = u32_safe_divmod(offset, nonzero_16);
        let (final_chunk, mut offset_in_chunk_f) = u32_safe_divmod(
            offset + elements_len - 1, nonzero_16
        );
        offset_in_chunk_f += 1;
        let mask_i: u256 = helpers::pow256_rev(offset_in_chunk_i);
        let mask_f: u256 = helpers::pow256_rev(offset_in_chunk_f);

        // Special case: within the same word.
        if initial_chunk == final_chunk {
            let w: u128 = self.items.get(initial_chunk.into());
            let w_l = w.into() % mask_i;
            let w_lh = w_l / mask_f;
            helpers::split_word(w_lh, elements_len, ref elements);
            return;
        }

        // Otherwise.
        // Get first word.
        let w_i = self.items.get(initial_chunk.into());
        let w_i_l = (w_i.into() % mask_i);
        let _elements_first_word = helpers::split_word(w_i_l, 16 - offset_in_chunk_i, ref elements);

        // Get blocks.
        self.load_aligned_words(initial_chunk + 1, final_chunk, ref elements);

        // Get last word.
        let w_f = self.items.get(final_chunk.into());
        let w_f_h = w_f.into() / mask_f;
        //TODO investigate why these two variables are not used
        let _elements_last_word = helpers::split_word(w_f_h, offset_in_chunk_f, ref elements);
    }


    /// Expands the memory by a specified length
    ///
    /// The function updates the `bytes_len` field of the `Memory` instance to reflect the new size
    /// of the memory chunk,
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to expand.
    /// * `length` - The length to expand the memory chunk by.
    #[inline(always)]
    fn expand(ref self: Memory, length: usize) {
        if (length == 0) {
            return;
        }

        let adjusted_length = (((length + 31) / 32) * 32);
        let new_bytes_len = self.size() + adjusted_length;

        // Update memory size.
        self.bytes_len = new_bytes_len;
    }


    /// Stores the first word of a span of bytes in the memory chunk at a specified offset.
    /// The function computes the high part of the word by dividing the current word at the
    /// specified offset by the mask, and computes the low part of the word by loading the remaining
    /// bytes from the span of bytes. It then combines the high and low parts of the word using the
    /// mask and stores the resulting word in the memory chunk at the specified offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the word in.
    /// * `chunk_index` - The index of the memory chunk to store the word in.
    /// * `start_offset_in_chunk` - The offset within the chunk to store the word at.
    /// * `start_mask` - The mask for the high part of the word.
    /// * `elements` - A span of bytes to store.
    ///
    /// # Panics
    ///
    /// This function panics if the resulting word cannot be converted to a `u128` - which should
    /// never happen.
    #[inline(always)]
    fn store_first_word(
        ref self: Memory,
        chunk_index: usize,
        start_offset_in_chunk: usize,
        start_mask: u256,
        elements: Span<u8>
    ) {
        let word = self.items.get(chunk_index.into());
        let word_high = (word.into() / start_mask);

        let bytes_to_read = 16 - start_offset_in_chunk;

        let word_low: u128 = elements
            .slice(0, bytes_to_read)
            .from_be_bytes_partial()
            .expect('Failed to parse word_low');

        let new_word: u128 = (word_high * start_mask + word_low.into()).try_into().unwrap();
        self.items.insert(chunk_index.into(), new_word);
    }

    /// Stores the last word of a span of bytes in the memory chunk at a specified offset.
    /// The function computes the low part of the word by taking the current word at the specified
    /// offset modulo the mask, and computes the high part of the word by loading the remaining
    /// bytes from the span of bytes. It then combines the high and low parts of the word using the
    /// mask and stores the resulting word in the memory chunk at the specified offset.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `Memory` instance to store the word in.
    /// * `chunk_index` - The index of the memory chunk to store the word in.
    /// * `end_offset_in_chunk` - The offset within the chunk to store the word at.
    /// * `end_mask` - The mask for the low part of the word.
    /// * `elements` - A span of bytes to store.
    ///
    /// # Panics
    ///
    /// This function panics if the resulting word cannot be converted to a `u128` - which should
    /// never happen.
    #[inline(always)]
    fn store_last_word(
        ref self: Memory,
        chunk_index: usize,
        end_offset_in_chunk: usize,
        end_mask: u256,
        elements: Span<u8>
    ) {
        let word = self.items.get(chunk_index.into());
        let word_low = (word.into() % end_mask);

        let low_bytes: u128 = elements
            .slice(0, end_offset_in_chunk)
            .from_be_bytes_partial()
            .expect('Failed to parse low_bytes');
        let new_word: u128 = (low_bytes.into() * end_mask + word_low).try_into().unwrap();
        self.items.insert(chunk_index.into(), new_word);
    }
}

#[generate_trait]
impl Felt252DictExtensionImpl of Felt252DictExtension {
    /// Stores a u256 element into the dictionary.
    /// The element will be stored as two distinct u128 elements,
    /// thus taking two indexes.
    ///
    /// # Arguments
    /// * `self` - A mutable reference to the `Felt252Dict` instance.
    /// * `element` - The element to store, of type `u256`.
    /// * `index` - The `usize` index at which to store the element.
    #[inline(always)]
    fn store_u256(ref self: Felt252Dict<u128>, element: u256, index: usize) {
        let index: felt252 = index.into();
        self.insert(index, element.high.into());
        self.insert(index + 1, element.low.into());
    }

    /// Reads a u256 element from the dictionary.
    /// The element is stored as two distinct u128 elements,
    /// thus we have to read the low and high parts and combine them.
    /// The memory is big-endian organized, so the high part is stored first.
    ///
    /// # Arguments
    /// * `self` - A mutable reference to the `Felt252Dict` instance.
    /// * `index` - The `usize` index at which the element is stored.
    ///
    /// # Returns
    /// * The element read, of type `u256`.
    #[inline(always)]
    fn read_u256(ref self: Felt252Dict<u128>, index: usize) -> u256 {
        let index: felt252 = index.into();
        let high: u128 = self.get(index);
        let low: u128 = self.get(index + 1);
        u256 { low: low, high: high }
    }
}


#[cfg(test)]
mod tests {
    use core::num::traits::Bounded;
    use crate::memory::{MemoryTrait, InternalMemoryTrait};
    use utils::constants::{POW_2_8, POW_2_56, POW_2_64, POW_2_120};
    use utils::{
        math::Exponentiation, math::WrappingExponentiation, helpers, traits::array::SpanExtTrait
    };


    fn load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
        offset: usize, low: u128, high: u128
    ) {
        // Given
        let mut memory = MemoryTrait::new();

        let value: u256 = u256 { low: low, high: high };

        let bytes_array = helpers::u256_to_bytes_array(value);

        memory.store_n(bytes_array.span(), offset);

        // When
        let mut elements: Array<u8> = Default::default();
        memory.load_n_internal(32, ref elements, offset);

        // Then
        assert(elements == bytes_array, 'result not matching expected');
    }

    fn load_should_load_an_element_from_the_memory_with_offset_stored_with_store(
        offset: usize, low: u128, high: u128, active_segment: usize,
    ) {
        // Given
        let mut memory = MemoryTrait::new();

        let value: u256 = u256 { low: low, high: high };

        memory.store(value, offset);

        // When
        let result: u256 = memory.load_internal(offset);

        // Then
        assert(result == value, 'result not matching expected');
    }


    #[test]
    fn test_init_should_return_an_empty_memory() {
        // When
        let mut result = MemoryTrait::new();

        // Then
        assert(result.size() == 0, 'memory not empty');
    }

    #[test]
    fn test_len_should_return_the_length_of_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let result = memory.size();

        // Then
        assert(result == 0, 'memory not empty');
    }

    #[test]
    fn test_store_should_add_an_element_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let value: u256 = 1;
        memory.store(value, 0);

        // Then
        assert_eq!(memory.items.get(0), 0);
        assert_eq!(memory.items.get(1), 1);
    }

    #[test]
    fn test_store_should_add_an_element_with_offset_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let value: u256 = 1;
        let offset = 1;
        memory.store(value, offset);

        // Then
        let internal_index = offset / 2;
        assert_eq!(memory.items.get(internal_index.into()), 0);
        assert_eq!(memory.items.get(internal_index.into() + 1), 0);
        assert_eq!(memory.items.get(internal_index.into() + 2), 0x01000000000000000000000000000000);
    }

    #[test]
    fn test_store_should_add_n_elements_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let value: u256 = 1;
        let offset = 0;
        let bytes_array = helpers::u256_to_bytes_array(value);
        memory.store_n(bytes_array.span(), offset);

        // Then
        let internal_index = offset / 2;
        assert_eq!(memory.items.get(internal_index.into()), 0);
        assert_eq!(memory.items.get(internal_index.into() + 1), 1);
    }


    #[test]
    fn test_store_n_no_aligned_words() {
        let mut memory = MemoryTrait::new();
        let byte_offset = 15;
        memory.store_n([1, 2].span(), byte_offset);

        let internal_index = byte_offset / 16;
        assert_eq!(memory.items.get(internal_index.into()), 0x01);
        assert_eq!(memory.items.get(internal_index.into() + 1), 0x02000000000000000000000000000000);
    }

    #[test]
    fn test_store_n_2_aligned_words() {
        let mut memory = MemoryTrait::new();
        let bytes_arr = [
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10,
            11,
            12,
            13,
            14,
            15,
            16,
            17,
            18,
            19,
            20,
            21,
            22,
            23,
            24,
            25,
            26,
            27,
            28,
            29,
            30,
            31,
            32,
            33,
            34,
            35
        ].span();
        memory.store_n(bytes_arr, 15);
        // value [1], will be stored in first word, values [2:34] will be stored in aligned words,
        // value [35] will be stored in final word

        let mut stored_bytes = Default::default();
        memory.load_n_internal(35, ref stored_bytes, 15);
        assert(stored_bytes.span() == bytes_arr, 'stored bytes not == expected');
    }

    #[test]
    fn test_load_n_internal_same_word() {
        let mut memory = MemoryTrait::new();
        memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

        let mut results: Array<u8> = ArrayTrait::new();
        memory.load_n_internal(16, ref results, 0);

        assert(results.len() == 16, 'error');
        for result in results {
            assert(result == 0xFF, 'byte value loaded not correct');
        }
    }


    #[test]
    fn test_load_should_load_an_element_from_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();
        // In the memory, the following values are stored in the order 1, 2, 3, 4 (Big Endian)
        let first_value: u256 = u256 { low: 2, high: 1 };
        let second_value = u256 { low: 4, high: 3 };
        let first_bytes_array = helpers::u256_to_bytes_array(first_value);
        let second_bytes_array = helpers::u256_to_bytes_array(second_value);
        memory.store_n(first_bytes_array.span(), 0);

        memory.store_n(second_bytes_array.span(), 32);

        // When
        let result: u256 = memory.load_internal(0);

        // Then
        assert(result == first_value, 'res not u256{2,1}');

        // When
        let result: u256 = memory.load_internal(32);

        // Then
        assert(result == second_value, 'res not u256{4,3}');

        // When
        let result: u256 = memory.load_internal(16);

        // Then
        assert(result == u256 { low: 3, high: 2 }, 'res not u256{3,2}');
    }

    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_8() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
            8, 2 * POW_2_64, POW_2_64
        );
    }
    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_7() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
            7, 2 * POW_2_56, POW_2_56
        );
    }
    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_23() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
            23, 3 * POW_2_56, 2 * POW_2_56
        );
    }

    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_33() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
            33, 4 * POW_2_8, 3 * POW_2_8
        );
    }
    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_63() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(
            63, 0, 4 * POW_2_120
        );
    }

    #[test]
    fn test_load_should_load_an_element_from_the_memory_with_offset_500() {
        load_should_load_an_element_from_the_memory_with_offset_stored_with_store_n(500, 0, 0);
    }


    #[test]
    fn test_expand__should_return_the_same_memory_and_no_cost() {
        // Given
        let mut memory = MemoryTrait::new();
        let value: u256 = 1;
        let bytes_array = helpers::u256_to_bytes_array(value);
        memory.bytes_len = 32;
        memory.store_n(bytes_array.span(), 0);

        // When
        memory.expand(0);

        // Then
        assert(memory.size() == 32, 'memory should be 32bytes');
        let value = memory.load_internal(0);
        assert(value == 1, 'value should be 1');
    }

    #[test]
    fn test_expand__should_return_expanded_memory_by_one_word() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.expand(1);

        // Then
        assert_eq!(memory.size(), 32);
    }

    #[test]
    fn test_expand__should_return_expanded_memory_by_exactly_one_word_and_cost() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.expand(32);

        // Then
        assert_eq!(memory.size(), 32);
    }

    #[test]
    fn test_expand__should_return_expanded_memory_by_two_words_and_cost() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.expand(33);

        // Then
        assert_eq!(memory.size(), 64);
    }

    #[test]
    fn test_ensure_length__should_return_the_same_memory_and_no_cost() {
        // Given
        let mut memory = MemoryTrait::new();
        let value: u256 = 1;
        let bytes_array = helpers::u256_to_bytes_array(value);

        memory.bytes_len = 32;
        memory.store_n(bytes_array.span(), 0);

        // When
        memory.ensure_length(1);

        // Then
        assert_eq!(memory.size(), 32);
        let value = memory.load_internal(0);
        assert_eq!(value, 1);
    }

    #[test]
    fn test_ensure_length__should_return_expanded_memory_and_cost() {
        // Given
        let mut memory = MemoryTrait::new();
        let value: u256 = 1;
        let bytes_array = helpers::u256_to_bytes_array(value);

        memory.bytes_len = 32;
        memory.store_n(bytes_array.span(), 0);

        // When
        memory.ensure_length(33);

        // Then
        assert_eq!(memory.size(), 64);
        let value = memory.load_internal(0);
        assert_eq!(value, 1);
    }

    #[test]
    fn test_load_should_return_element() {
        // Given
        let mut memory = MemoryTrait::new();
        let value: u256 = 1;
        let bytes_array = helpers::u256_to_bytes_array(value);
        memory.bytes_len = 32;
        memory.store_n(bytes_array.span(), 0);

        // When
        let value = memory.load(32);

        // Then
        assert_eq!(value, 0);
    }

    #[test]
    fn test_store_padded_segment_should_not_change_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let bytes = [1, 2, 3, 4, 5].span();
        memory.store_padded_segment(0, 0, bytes);

        // Then
        let item_0 = memory.items.get(0);
        let item_1 = memory.items.get(1);
        assert_eq!(item_0, 0);
        assert_eq!(item_1, 0);
    }

    #[test]
    fn test_store_padded_segment_should_write_to_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let bytes = [].span();
        memory.store_padded_segment(10, 10, bytes);

        // Then
        let word = memory.load(10);
        assert_eq!(word, 0);
    }

    #[test]
    fn test_store_padded_segment_should_add_n_elements_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        let bytes = [1, 2, 3, 4, 5].span();
        memory.store_padded_segment(0, 5, bytes);

        // Then
        let first_word = memory.load_internal(0);
        assert(
            first_word == 0x0102030405000000000000000000000000000000000000000000000000000000,
            'Wrong memory value'
        );
    }

    #[test]
    fn test_store_padded_segment_should_add_n_elements_padded_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // Memory initialization with a value to verify that if the size is out of the bound bytes,
        // 0's have been copied.
        // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
        memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

        // When
        let bytes = [1, 2, 3, 4, 5].span();
        memory.store_padded_segment(0, 10, bytes);

        // Then
        let first_word = memory.load_internal(0);
        assert(
            first_word == 0x01020304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'Wrong memory value'
        );
    }

    #[test]
    fn test_store_padded_segment_should_add_n_elements_padded_with_offset_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // Memory initialization with a value to verify that if the size is out of the bound bytes,
        // 0's have been copied.
        // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
        memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);

        // When
        let bytes = [1, 2, 3, 4, 5].span();
        memory.store_padded_segment(5, 10, bytes);

        let first_word = memory.load_internal(0);
        assert(
            first_word == 0xFFFFFFFFFF01020304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'Wrong memory value'
        );
    }

    #[test]
    fn test_store_padded_segment_should_add_n_elements_padded_with_offset_between_two_words_to_the_memory() {
        // Given
        let mut memory = MemoryTrait::new();

        // Memory initialization with a value to verify that if the size is out of the bound bytes,
        // 0's have been copied.
        // Otherwise, the memory value would be 0, and we wouldn't be able to check it.
        memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0);
        memory.store(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 32);

        // When
        let bytes = [1, 2, 3, 4, 5].span();
        memory.store_padded_segment(30, 10, bytes);

        // Then
        let first_word = memory.load_internal(0);
        assert(
            first_word == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0102,
            'Wrong memory value'
        );

        let second_word = memory.load_internal(32);
        assert(
            second_word == 0x0304050000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            'Wrong memory value'
        );
    }


    #[test]
    fn test_store_byte_should_store_byte_at_offset() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.store_byte(0x01, 15);

        // Then
        assert(memory.items[0] == 0x01, 'Wrong value for word 0');
        assert(memory.items[1] == 0x00, 'Wrong value for word 1');
    }
    #[test]
    fn test_store_byte_should_store_byte_at_offset_2() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.store_byte(0xff, 14);

        // Then
        assert(memory.items[0] == 0xff00, 'Wrong value for word 0');
        assert(memory.items[1] == 0x00, 'Wrong value for word 1');
    }

    #[test]
    fn test_store_byte_should_store_byte_at_offset_in_existing_word() {
        // Given
        let mut memory = MemoryTrait::new();
        memory.items.insert(0, 0xFFFF); // Set the first word in memory to 0xFFFF;
        memory.items.insert(1, 0xFFFF);

        // When
        memory.store_byte(0x01, 30);

        // Then
        assert(memory.items[0] == 0xFFFF, 'Wrong value for word 0');
        assert(memory.items[1] == 0x01FF, 'Wrong value for word 1');
    }

    #[test]
    fn test_store_byte_should_store_byte_at_offset_in_new_word() {
        // Given
        let mut memory = MemoryTrait::new();

        // When
        memory.store_byte(0x01, 32);

        // Then
        assert(memory.items[0] == 0x0, 'Wrong value for word 0');
        assert(memory.items[1] == 0x0, 'Wrong value for word 1');
        assert(memory.items[2] == 0x01000000000000000000000000000000, 'Wrong value for word 2');
    }

    #[test]
    fn test_store_byte_should_store_byte_at_offset_in_new_word_with_existing_value_in_previous_word() {
        // Given
        let mut memory = MemoryTrait::new();
        memory.items.insert(0, 0x0100);
        memory.items.insert(1, 0xffffffffffffffffffffffffffffffff);

        // When
        memory.store_byte(0xAB, 17);

        // Then
        assert(memory.items[0] == 0x0100, 'Wrong value in word 0');
        assert(memory.items[1] == 0xffABffffffffffffffffffffffffffff, 'Wrong value in word 1');
    }
}
