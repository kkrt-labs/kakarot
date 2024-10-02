use core::cmp::min;
//! SHA3.
use core::keccak::{cairo_keccak};
use core::num::traits::CheckedAdd;

// Internal imports
use crate::errors::EVMError;
use crate::gas;
use crate::memory::MemoryTrait;
use crate::model::vm::{VM, VMTrait};
use crate::stack::StackTrait;
use utils::helpers::bytes_32_words_size;
use utils::traits::array::ArrayExtTrait;
use utils::traits::integer::U256Trait;
#[generate_trait]
pub impl Sha3Impl of Sha3Trait {
    /// SHA3 operation : Hashes n bytes in memory at a given offset in memory
    /// and push the hash result to the stack.
    ///
    /// # Inputs
    /// * `offset` - The offset in memory where to read the data
    /// * `size` - The amount of bytes to read
    ///
    /// # Specification: https://www.evm.codes/#20?fork=shanghai
    fn exec_sha3(ref self: VM) -> Result<(), EVMError> {
        let offset: usize = self.stack.pop_saturating_usize()?;
        let mut size: usize = self
            .stack
            .pop_usize()?; // Any size bigger than a usize would MemoryOOG.

        let words_size = bytes_32_words_size(size).into();
        let word_gas_cost = gas::KECCAK256WORD * words_size;
        let memory_expansion = gas::memory_expansion(self.memory.size(), [(offset, size)].span())?;
        self.memory.ensure_length(memory_expansion.new_size);
        let total_cost = gas::KECCAK256
            .checked_add(word_gas_cost)
            .ok_or(EVMError::OutOfGas)?
            .checked_add(memory_expansion.expansion_cost)
            .ok_or(EVMError::OutOfGas)?;
        self.charge_gas(total_cost)?;

        let mut to_hash: Array<u64> = Default::default();

        let (nb_words, nb_zeroes) = compute_memory_words_amount(size, offset, self.memory.size());
        let mut last_input_offset = fill_array_with_memory_words(
            ref self, ref to_hash, offset, nb_words
        );
        // Fill array to hash with zeroes for bytes out of memory bound
        // which is faster than reading them from memory
        to_hash.append_n(0, 4 * nb_zeroes);

        // For cases where the size of bytes to hash isn't a multiple of 8,
        // prepare the last bytes to hash into last_input instead of appending
        // it to to_hash.
        let last_input: u64 = if (size % 32 != 0) {
            let loaded = self.memory.load(last_input_offset);
            prepare_last_input(ref to_hash, loaded, size % 32)
        } else {
            0
        };
        // Properly set the memory length in case we skipped reading zeroes
        self.memory.ensure_length(size + offset);
        let mut hash = cairo_keccak(ref to_hash, last_input, size % 8);
        self.stack.push(hash.reverse_endianness())
    }
}


/// Computes how many words are read from the memory
/// and how many words must be filled with zeroes
/// given a target size, a memory offset and the length of the memory.
///
/// # Arguments
///
/// * `size` - The amount of bytes to hash
/// * `offset` - Offset in memory
/// * `mem_len` - Size of the memory
/// Returns : (nb_words, nb_zeroes)
fn compute_memory_words_amount(size: u32, offset: u32, mem_len: u32) -> (u32, u32) {
    // Bytes to hash are less than a word size
    if size < 32 {
        return (0, 0);
    }
    // Bytes out of memory bound are zeroes
    if offset > mem_len {
        return (0, size / 32);
    }
    // The only word to read from memory is less than 32 bytes
    if mem_len - offset < 32 {
        return (1, (size / 32) - 1);
    }

    let bytes_to_read = min(mem_len - offset, size);
    let nb_words = bytes_to_read / 32;
    (nb_words, (size / 32) - nb_words)
}

/// Fills the `to_hash` array with little endian u64s
/// by splitting words read from the memory and
/// returns the next offset to read from.
///
/// # Arguments
///
/// * `self` - The context in which the memory is read
/// * `to_hash` - A reference to the array to fill
/// * `offset` - Offset in memory to start reading from
/// * `amount` - The amount of words to read from memory
/// Return the new offset
fn fill_array_with_memory_words(
    ref self: VM, ref to_hash: Array<u64>, mut offset: u32, mut amount: u32
) -> u32 {
    for _ in 0
        ..amount {
            let loaded = self.memory.load(offset);
            let ((high_h, low_h), (high_l, low_l)) = loaded.split_into_u64_le();
            to_hash.append(low_h);
            to_hash.append(high_h);
            to_hash.append(low_l);
            to_hash.append(high_l);

            offset += 32;
        };
    offset
}

/// Fills the `to_hash` array with the n-1 remaining little endian u64
/// depending on size from a word and returns
/// the u64 containing the last 8 bytes word to hash.
///
/// # Arguments
///
/// * `to_hash` - A reference to the array to fill
/// * `value` - The word to split in u64 words
/// * `size` - The amount of bytes still required to hash
/// Returns the last u64 word that isn't 8 Bytes long.
fn prepare_last_input(ref to_hash: Array<u64>, value: u256, size: u32) -> u64 {
    let ((high_h, low_h), (high_l, low_l)) = value.split_into_u64_le();
    if size < 8 {
        return low_h;
    } else if size < 16 {
        to_hash.append(low_h);
        return high_h;
    } else if size < 24 {
        to_hash.append(low_h);
        to_hash.append(high_h);
        return low_l;
    } else {
        to_hash.append(low_h);
        to_hash.append(high_h);
        to_hash.append(low_l);
        return high_l;
    }
}

#[cfg(test)]
mod tests {
    use crate::instructions::Sha3Trait;
    use crate::instructions::sha3;
    use crate::memory::MemoryTrait;
    use crate::stack::StackTrait;
    use crate::test_utils::{VMBuilderTrait, MemoryTestUtilsTrait};

    #[test]
    fn test_exec_sha3_size_0_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x00).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();

        assert(
            result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
            'wrong result'
        );
        assert(vm.memory.size() == 32, 'wrong memory size');
    }


    #[test]
    fn test_exec_sha3_should_not_expand_memory() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x05).expect('push failed');
        vm.stack.push(0x04).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert_eq!(result, 0xc41589e7559804ea4a2080dad19d876a024ccb05117835447d72ce08c1d020ec);
        assert_eq!(vm.memory.size(), 32);
    }

    #[test]
    fn test_exec_sha3_should_expand_memory() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(24).expect('push failed');
        vm.stack.push(10).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert_eq!(result, 0x827b659bbda2a0bdecce2c91b8b68462545758f3eba2dbefef18e0daf84f5ccd);
        assert_eq!(vm.memory.size(), 64);
    }

    #[test]
    fn test_exec_sha3_size_0xFFFFF_offset_1000() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0xFFFFF).expect('push failed');
        vm.stack.push(1000).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0xbe6f1b42b34644f918560a07f959d23e532dea5338e4b9f63db0caeb608018fa,
            'wrong result'
        );
        assert(vm.memory.size() == (((0xFFFFF + 1000) + 31) / 32) * 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_1000000_offset_2() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(1000000).expect('push failed');
        vm.stack.push(2).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x4aa461ae9513f3b03ae397740ade979809dd02ae2c14e101b32842fbee21f0a,
            'wrong result'
        );
        assert(vm.memory.size() == (((1000000 + 2) + 31) / 32) * 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_1000000_offset_23() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(1000000).expect('push failed');
        vm.stack.push(2).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );
        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x4aa461ae9513f3b03ae397740ade979809dd02ae2c14e101b32842fbee21f0a,
            'wrong result'
        );
        assert(vm.memory.size() == (((1000000 + 23) + 31) / 32) * 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_1_offset_2048() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(1).expect('push failed');
        vm.stack.push(2048).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a,
            'wrong result'
        );
        assert(vm.memory.size() == (((2048 + 1) + 31) / 32) * 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_0_offset_1024() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0).expect('push failed');
        vm.stack.push(1024).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,
            'wrong result'
        );
        assert(vm.memory.size() == 1024, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_32_offset_2016() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(32).expect('push failed');
        vm.stack.push(2016).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFFFFFFFF00000000000000000000000000000000000000000000000000000000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563,
            'wrong result'
        );
        assert(vm.memory.size() == (((2016 + 32) + 31) / 32) * 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_32_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(32).expect('push failed');
        vm.stack.push(0).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x567d6b045256961aee949d6bb4d5f814c5b42e6b8bb49a833e8e89fbcddee86c,
            'wrong result'
        );
        assert(vm.memory.size() == 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_31_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(31).expect('push failed');
        vm.stack.push(0).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x4b13f212816c02cc818ba4802e81a4ac1904d2c920fe8d8cf3e4f05233a57d2e,
            'wrong result'
        );
        assert(vm.memory.size() == 32, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_33_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(33).expect('push failed');
        vm.stack.push(0).expect('push failed');

        vm
            .memory
            .store_with_expansion(
                0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0
            );

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0xa6fa3edfabbe64b6ce26120b21ac9b8191005115d5e7e03fa58ec9cc74c0f2f4,
            'wrong result'
        );
        assert(vm.memory.size() == 64, 'wrong memory size');
    }

    #[test]
    fn test_exec_sha3_size_0x0C80_offset_0() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x0C80).expect('push failed');
        vm.stack.push(0x00).expect('push failed');

        let mut mem_dst: u32 = 0;
        while mem_dst <= 0x0C80 {
            vm
                .memory
                .store_with_expansion(
                    0xFAFAFAFA00000000000000000000000000000000000000000000000000000000, mem_dst
                );
            mem_dst += 0x20;
        };

        // When
        vm.exec_sha3().expect('exec_sha3 failed');

        // Then
        let result = vm.stack.peek().unwrap();
        assert(
            result == 0x2022ae07f3a362b08ac0a4bcb785c830cb5c368dc0ce6972249c6abbc68a5291,
            'wrong result'
        );
        assert(vm.memory.size() == 0x0C80 + 32, 'wrong memory size');
    }

    #[test]
    fn test_internal_fill_array_with_memory_words() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let mut to_hash: Array<u64> = Default::default();

        vm
            .memory
            .store_with_expansion(
                0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0
            );
        let mut size = 32;
        let mut offset = 0;

        // When
        let (words_from_mem, _) = sha3::compute_memory_words_amount(size, offset, vm.memory.size());
        sha3::fill_array_with_memory_words(ref vm, ref to_hash, offset, words_from_mem);

        // Then
        assert(to_hash.len() == 4, 'wrong array length');
        assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
        assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
        assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
        assert((*to_hash[3]) == 0x0000450000DEFA00, 'wrong array value');
    }

    #[test]
    fn test_internal_fill_array_with_memory_words_size_33() {
        // Given
        let mut vm = VMBuilderTrait::new_with_presets().build();
        let mut to_hash: Array<u64> = Default::default();

        vm
            .memory
            .store_with_expansion(
                0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000, 0
            );
        let mut size = 33;
        let mut offset = 0;

        // When
        let (words_from_mem, _) = sha3::compute_memory_words_amount(size, offset, vm.memory.size());
        sha3::fill_array_with_memory_words(ref vm, ref to_hash, offset, words_from_mem);

        // Then
        assert(to_hash.len() == 4, 'wrong array length');
        assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
        assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
        assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
        assert((*to_hash[3]) == 0x0000450000DEFA00, 'wrong array value');
    }

    #[test]
    fn test_internal_fill_array_with_last_inputs_size_5() {
        // Given
        let mut to_hash: Array<u64> = Default::default();
        let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
        let size = 5;

        // When
        let result = sha3::prepare_last_input(ref to_hash, value, size);

        // Then
        assert(result == 0xE5000000FFFFFFFA, 'wrong result');
        assert(to_hash.len() == 0, 'wrong result');
    }

    #[test]
    fn test_internal_fill_array_with_last_inputs_size_20() {
        // Given
        let mut to_hash: Array<u64> = Default::default();
        let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
        let size = 20;

        // When
        let result = sha3::prepare_last_input(ref to_hash, value, size);

        // Then
        assert(result == 0x00200400000000AD, 'wrong result');
        assert(to_hash.len() == 2, 'wrong result');
        assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
        assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
    }

    #[test]
    fn test_internal_fill_array_with_last_inputs_size_50() {
        // Given
        let mut to_hash: Array<u64> = Default::default();
        let value: u256 = 0xFAFFFFFF000000E500000077000000DEAD0000000004200000FADE0000450000;
        let size = 50;

        // When
        let result = sha3::prepare_last_input(ref to_hash, value, size);

        // Then
        assert(result == 0x0000450000DEFA00, 'wrong result');
        assert(to_hash.len() == 3, 'wrong result');
        assert((*to_hash[0]) == 0xE5000000FFFFFFFA, 'wrong array value');
        assert((*to_hash[1]) == 0xDE00000077000000, 'wrong array value');
        assert((*to_hash[2]) == 0x00200400000000AD, 'wrong array value');
    }
}
