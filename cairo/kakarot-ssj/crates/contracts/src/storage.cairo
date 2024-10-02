use core::ops::DerefMut;
use core::ops::SnapshotDeref;
use core::starknet::storage::{
    StoragePointerReadAccess, StoragePointerWriteAccess, StorageTrait, StorageTraitMut
};
use core::starknet::storage_access::StorageBaseAddress;
use core::starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use core::starknet::{SyscallResult, Store, StorageAddress};
use crate::account_contract::AccountContract::unsafe_new_contract_state as account_contract_state;
use utils::utils::{pack_bytes, load_packed_bytes};

/// A wrapper type for the bytecode storage. Packing / unpacking is done transparently inside the
/// `read` and `write` methods of `Store`.
#[derive(Copy, Drop)]
pub struct StorageBytecode {
    pub bytecode: Span<u8>
}

const BYTES_PER_FELT: NonZero<u32> = 31;

/// An implementation of the `Store` trait for our specific `StorageBytecode` type.
/// The packing-unpacking is done inside the `read` and `write` methods, thus transparent to the
/// user.
/// The bytecode is stored sequentially, starting from storage address 0, for compatibility purposes
/// with KakarotZero.
/// The bytecode length is stored in the `Account_bytecode_len` storage variable, which is accessed
/// by the `read` and `write` methods.
impl StoreBytecode of Store<StorageBytecode> {
    /// Side effect: reads the bytecode len from the Account_bytecode_len storage variable
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<StorageBytecode> {
        // Read the bytecode len from the storage of the current contract
        let state = account_contract_state();
        let bytecode_len: u32 = state.snapshot_deref().storage().Account_bytecode_len.read();
        let (chunks_count, _remainder) = DivRem::div_rem(bytecode_len, BYTES_PER_FELT);

        // Read the bytecode from the storage of the current contract, starting from address 0.
        //TODO(opti): unpack chunks directly instead of reading them one by one and unpacking them
        // afterwards.
        let base: felt252 = 0;
        let mut packed_bytecode = array![];
        for i in 0
            ..chunks_count
                + 1 {
                    let storage_address: StorageAddress = (base + i.into()).try_into().unwrap();
                    let chunk = storage_read_syscall(address_domain, storage_address).unwrap();
                    packed_bytecode.append(chunk);
                };
        let bytecode = load_packed_bytes(packed_bytecode.span(), bytecode_len);
        SyscallResult::Ok(StorageBytecode { bytecode: bytecode.span() })
    }

    /// Side effect: Writes the bytecode len to the Account_bytecode_len storage variable
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: StorageBytecode
    ) -> SyscallResult<()> {
        let base: felt252 = 0;
        let mut state = account_contract_state();
        let bytecode_len: u32 = value.bytecode.len();
        state.deref_mut().storage_mut().Account_bytecode_len.write(bytecode_len);

        let mut packed_bytecode = pack_bytes(value.bytecode);
        let mut i = 0;
        for chunk in packed_bytecode {
            let storage_address: StorageAddress = (base + i.into()).try_into().unwrap();
            storage_write_syscall(address_domain, storage_address, chunk).unwrap();
            i += 1;
        };
        SyscallResult::Ok(())
    }

    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<StorageBytecode> {
        panic!("'read_at_offset' is not implemented for StoreBytecode")
    }

    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: StorageBytecode
    ) -> SyscallResult<()> {
        panic!("'write_at_offset' is not implemented for StoreBytecode")
    }

    fn size() -> u8 {
        panic!("'size' is not implemented for StoreBytecode")
    }
}

#[cfg(test)]
mod tests {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::account_contract::AccountContract::unsafe_new_contract_state as account_contract_state;
    use starknet::storage_access::Store;
    use starknet::storage_access::{
        StorageBaseAddress, StorageAddress, storage_base_address_from_felt252
    };
    use starknet::syscalls::storage_read_syscall;
    use super::DerefMut;
    use super::SnapshotDeref;
    use super::StorageBytecode;
    use super::StorageTrait;
    use super::StorageTraitMut;
    use utils::utils::pack_bytes;

    #[test]
    fn test_store_bytecode_empty() {
        let mut state = account_contract_state();
        let bytecode = [].span();
        // Write the bytecode to the storage
        state.deref_mut().storage_mut().Account_bytecode.write(StorageBytecode { bytecode });
        // Verify that the bytecode was written correctly and the len as well
        let bytecode_len = state.snapshot_deref().storage().Account_bytecode_len.read();
        let stored_bytecode = state.snapshot_deref().storage().Account_bytecode.read();
        assert_eq!(bytecode_len, bytecode.len());
        assert_eq!(stored_bytecode.bytecode, bytecode);
    }

    #[test]
    fn test_store_bytecode_single_chunk() {
        let mut state = account_contract_state();
        let bytecode = [0, 1, 2, 3, 4, 5].span();
        // Write the bytecode to the storage
        state.deref_mut().storage_mut().Account_bytecode.write(StorageBytecode { bytecode });
        // Verify that the bytecode was written correctly and the len as well
        let bytecode_len = state.snapshot_deref().storage().Account_bytecode_len.read();
        let stored_bytecode = state.snapshot_deref().storage().Account_bytecode.read();
        assert_eq!(bytecode_len, bytecode.len());
        assert_eq!(stored_bytecode.bytecode, bytecode);
    }

    #[test]
    fn test_store_bytecode_multiple_chunks() {
        let mut state = account_contract_state();
        let mut bytecode_array = array![];
        for i in 0..100_u8 {
            bytecode_array.append(i);
        };
        let bytecode = bytecode_array.span();
        // Write the bytecode to the storage
        state.deref_mut().storage_mut().Account_bytecode.write(StorageBytecode { bytecode });
        // Verify that the bytecode was written correctly and the len as well
        let bytecode_len = state.snapshot_deref().storage().Account_bytecode_len.read();
        let stored_bytecode = state.snapshot_deref().storage().Account_bytecode.read();
        assert_eq!(bytecode_len, bytecode.len());
        assert_eq!(stored_bytecode.bytecode, bytecode);
    }

    #[test]
    fn test_store_bytecode_partial_chunk() {
        let mut state = account_contract_state();
        let bytecode = [
            1
        ; 33].span(); // 33 bytes will require 2 chunks, with the second chunk partially filled
        // Write the bytecode to the storage
        state.deref_mut().storage_mut().Account_bytecode.write(StorageBytecode { bytecode });
        // Verify that the bytecode was written correctly and the len as well
        let bytecode_len = state.snapshot_deref().storage().Account_bytecode_len.read();
        let stored_bytecode = state.snapshot_deref().storage().Account_bytecode.read();
        assert_eq!(bytecode_len, bytecode.len());
        assert_eq!(stored_bytecode.bytecode, bytecode);
    }

    #[test]
    fn test_storage_layout_sequential_from_zero() {
        let base_address: StorageAddress = 0.try_into().unwrap();
        let bytecode = [0x12; 33].span();
        let stored_bytecode = StorageBytecode { bytecode };
        let mut state = account_contract_state();
        state.deref_mut().storage_mut().Account_bytecode.write(stored_bytecode);

        // Verify that the bytecode was packed in chunks sequential from zero
        let chunk0 = storage_read_syscall(0, base_address).unwrap();
        let chunk1 = storage_read_syscall(0, 1.try_into().unwrap()).unwrap();

        assert_eq!(chunk0, (*pack_bytes([0x12; 31].span())[0]));
        assert_eq!(chunk1, 0x1212);
    }

    #[test]
    #[should_panic(expected: "'read_at_offset' is not implemented for StoreBytecode")]
    fn test_read_at_offset_panics() {
        let base_address: StorageBaseAddress = storage_base_address_from_felt252(0);
        let _ = Store::<StorageBytecode>::read_at_offset(0, base_address, 0);
    }

    #[test]
    #[should_panic(expected: "'write_at_offset' is not implemented for StoreBytecode")]
    fn test_write_at_offset_panics() {
        let base_address: StorageBaseAddress = storage_base_address_from_felt252(0);
        let bytecode = array![].span();
        let stored_bytecode = StorageBytecode { bytecode };
        let _ = Store::<StorageBytecode>::write_at_offset(0, base_address, 0, stored_bytecode);
    }

    #[test]
    #[should_panic(expected: "'size' is not implemented for StoreBytecode")]
    fn test_size_panics() {
        let _ = Store::<StorageBytecode>::size();
    }
}
