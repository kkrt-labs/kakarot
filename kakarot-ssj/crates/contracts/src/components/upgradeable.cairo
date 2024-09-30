use core::starknet::ClassHash;

#[starknet::interface]
pub trait IUpgradeable<TContractState> {
    fn upgrade_contract(ref self: TContractState, new_class_hash: ClassHash);
}


#[starknet::component]
pub mod upgradeable_component {
    use core::starknet::ClassHash;
    use core::starknet::syscalls::{replace_class_syscall};


    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContractUpgraded: ContractUpgraded
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUpgraded {
        new_class_hash: ClassHash
    }

    #[embeddable_as(Upgradeable)]
    pub impl UpgradeableImpl<
        TContractState, +HasComponent<TContractState>
    > of super::IUpgradeable<ComponentState<TContractState>> {
        fn upgrade_contract(
            ref self: ComponentState<TContractState>, new_class_hash: starknet::ClassHash
        ) {
            replace_class_syscall(new_class_hash).expect('replace class failed');
            self.emit(ContractUpgraded { new_class_hash: new_class_hash });
        }
    }
}
