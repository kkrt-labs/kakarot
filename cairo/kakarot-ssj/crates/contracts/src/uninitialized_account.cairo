//! The generic account that is deployed by Kakarot Core before being "specialized" into an
//! Externally Owned Account or a Contract Account This aims at having only one class hash for all
//! the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth
//! Address <=> Starknet Address

use core::starknet::ClassHash;
use core::starknet::{ContractAddress, EthAddress};

#[starknet::interface]
trait IAccount<TContractState> {
    fn initialize(
        ref self: TContractState,
        kakarot_address: ContractAddress,
        evm_address: EthAddress,
        implementation_class: ClassHash
    );
}


#[starknet::contract]
pub mod UninitializedAccount {
    use core::starknet::SyscallResultTrait;
    use core::starknet::syscalls::{library_call_syscall, replace_class_syscall};
    use core::starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use crate::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};

    // Add ownable component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl InternalImplOwnable = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, mut calldata: Array<felt252>) {
        let owner_address: ContractAddress = get_caller_address();
        self.ownable.initializer(owner_address);
        let implementation_class = IKakarotCoreDispatcher { contract_address: owner_address }
            .get_account_contract_class_hash();
        //TODO: Difference from KakarotZero in that the account contract takes the class
        //implementation to write it in storage,
        // as it is not a transparent proxy in Cairo1
        calldata.append(implementation_class.into());
        library_call_syscall(
            class_hash: implementation_class,
            function_selector: selector!("initialize"),
            calldata: calldata.span()
        )
            .unwrap_syscall();

        replace_class_syscall(implementation_class).unwrap_syscall();
    }
}
