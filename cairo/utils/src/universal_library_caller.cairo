use starknet::{
    SyscallResult, storage_access::StorageAddress, class_hash::ClassHash,
};


#[starknet::interface]
pub trait IUniversalLibraryCaller<TContractState> {
    fn library_call(self: @TContractState, class_hash: ClassHash, function_selector: felt252, calldata: Span<felt252>) ->  SyscallResult<Span<felt252>>;
}

#[starknet::contract]
pub mod UniversalLibraryCaller {
    use starknet::syscalls::library_call_syscall;
    use starknet::{
        SyscallResult, storage_access::StorageAddress, class_hash::ClassHash,
    };


    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl UniversalLibraryCallerImpl of super::IUniversalLibraryCaller<ContractState> {
        fn library_call(self: @ContractState, class_hash: ClassHash, function_selector: felt252, calldata: Span<felt252>) -> SyscallResult<Span<felt252>> {
            library_call_syscall(class_hash, function_selector, calldata)
        }
    }
}
