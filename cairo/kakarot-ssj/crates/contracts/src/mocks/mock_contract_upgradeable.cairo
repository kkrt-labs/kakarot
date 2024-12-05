#[starknet::interface]
pub trait IMockContractUpgradeable<TContractState> {
    fn version(self: @TContractState) -> felt252;
}

#[starknet::contract]
pub mod MockContractUpgradeableV1 {
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use starknet::{ClassHash};
    use super::IMockContractUpgradeable;
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[abi(embed_v0)]
    impl MockContractUpgradeableImpl of IMockContractUpgradeable<ContractState> {
        fn version(self: @ContractState) -> felt252 {
            1
        }
    }


    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
