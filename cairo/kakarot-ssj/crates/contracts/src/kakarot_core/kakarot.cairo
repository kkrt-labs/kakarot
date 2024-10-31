const INVOKE_ETH_CALL_FORBIDDEN: felt252 = 'KKT: Cannot invoke eth_call';


#[starknet::contract]
pub mod KakarotCore {
    use core::num::traits::Zero;
    use core::starknet::event::EventEmitter;
    use core::starknet::get_caller_address;
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use core::starknet::{EthAddress, ContractAddress, ClassHash, get_contract_address};
    use crate::kakarot_core::eth_rpc;
    use crate::kakarot_core::interface::IKakarotCore;
    use evm::backend::starknet_backend;
    use evm::model::account::AccountTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
    use utils::helpers::compute_starknet_address;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    /// STORAGE ///

    #[storage]
    pub struct Storage {
        pub Kakarot_evm_to_starknet_address: Map::<EthAddress, ContractAddress>,
        pub Kakarot_uninitialized_account_class_hash: ClassHash,
        pub Kakarot_account_contract_class_hash: ClassHash,
        pub Kakarot_native_token_address: ContractAddress,
        pub Kakarot_coinbase: EthAddress,
        pub Kakarot_base_fee: u64,
        pub Kakarot_prev_randao: u256,
        pub Kakarot_block_gas_limit: u64,
        // Components
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    /// EVENTS ///

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        AccountDeployed: AccountDeployed,
        AccountClassHashChange: AccountClassHashChange,
        EOAClassHashChange: EOAClassHashChange,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct AccountDeployed {
        #[key]
        pub evm_address: EthAddress,
        #[key]
        pub starknet_address: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct AccountClassHashChange {
        pub old_class_hash: ClassHash,
        pub new_class_hash: ClassHash,
    }


    #[derive(Copy, Drop, starknet::Event)]
    pub struct EOAClassHashChange {
        pub old_class_hash: ClassHash,
        pub new_class_hash: ClassHash,
    }


    /// Trait bounds allowing embedded implementations to be specific to this contract
    pub trait KakarotCoreState<TContractState> {
        fn get_state() -> ContractState;
    }

    impl _KakarotCoreState of KakarotCoreState<ContractState> {
        fn get_state() -> ContractState {
            unsafe_new_contract_state()
        }
    }

    /// CONSTRUCTOR ///

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        native_token: ContractAddress,
        account_contract_class_hash: ClassHash,
        uninitialized_account_class_hash: ClassHash,
        coinbase: EthAddress,
        block_gas_limit: u64,
        mut eoas_to_deploy: Span<EthAddress>,
    ) {
        self.ownable.initializer(owner);
        self.Kakarot_native_token_address.write(native_token);
        self.Kakarot_account_contract_class_hash.write(account_contract_class_hash);
        self.Kakarot_uninitialized_account_class_hash.write(uninitialized_account_class_hash);
        self.Kakarot_coinbase.write(coinbase);
        self.Kakarot_block_gas_limit.write(block_gas_limit);
        for eoa_address in eoas_to_deploy {
            self.deploy_externally_owned_account(*eoa_address);
        };
    }

    /// PUBLIC-FACING FUNCTIONS ///

    // Public-facing "ownable" functions
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl =
        OwnableComponent::OwnableCamelOnlyImpl<ContractState>;

    /// Public-facing "ethereum" functions
    /// Used to make EVM-related actions through Kakarot.
    #[abi(embed_v0)]
    pub impl EthRPCImpl = eth_rpc::EthRPC<ContractState>;


    /// Public-facing "kakarot" functions
    /// Used to interact with the Kakarot contract outside of EVM-related actions.
    #[abi(embed_v0)]
    pub impl KakarotCoreImpl of IKakarotCore<ContractState> {
        fn set_native_token(ref self: ContractState, native_token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.Kakarot_native_token_address.write(native_token);
        }

        fn get_native_token(self: @ContractState) -> ContractAddress {
            self.Kakarot_native_token_address.read()
        }

        fn address_registry(self: @ContractState, evm_address: EthAddress) -> ContractAddress {
            self.Kakarot_evm_to_starknet_address.read(evm_address)
        }

        fn deploy_externally_owned_account(
            ref self: ContractState, evm_address: EthAddress
        ) -> ContractAddress {
            starknet_backend::deploy(evm_address).expect('EOA Deployment failed').starknet
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }

        fn get_account_contract_class_hash(self: @ContractState) -> ClassHash {
            self.Kakarot_account_contract_class_hash.read()
        }

        fn set_account_contract_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.Kakarot_account_contract_class_hash.read();
            self.Kakarot_account_contract_class_hash.write(new_class_hash);
            self.emit(EOAClassHashChange { old_class_hash, new_class_hash });
        }

        fn uninitialized_account_class_hash(self: @ContractState) -> ClassHash {
            self.Kakarot_uninitialized_account_class_hash.read()
        }

        fn set_account_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            let old_class_hash = self.Kakarot_uninitialized_account_class_hash.read();
            self.Kakarot_uninitialized_account_class_hash.write(new_class_hash);
            self.emit(AccountClassHashChange { old_class_hash, new_class_hash });
        }

        fn register_account(ref self: ContractState, evm_address: EthAddress) {
            let existing_address = self.Kakarot_evm_to_starknet_address.read(evm_address);
            assert(existing_address.is_zero(), 'Account already exists');

            let starknet_address = compute_starknet_address(
                get_contract_address(),
                evm_address,
                self.Kakarot_uninitialized_account_class_hash.read()
            );
            assert!(
                starknet_address == get_caller_address(), "Account must be registered by the caller"
            );

            self.Kakarot_evm_to_starknet_address.write(evm_address, starknet_address);
            self.emit(AccountDeployed { evm_address, starknet_address });
        }

        fn get_block_gas_limit(self: @ContractState) -> u64 {
            self.Kakarot_block_gas_limit.read()
        }

        fn set_base_fee(ref self: ContractState, base_fee: u64) {
            self.ownable.assert_only_owner();
            self.Kakarot_base_fee.write(base_fee);
        }

        fn get_base_fee(self: @ContractState) -> u64 {
            self.Kakarot_base_fee.read()
        }


        fn get_starknet_address(self: @ContractState, evm_address: EthAddress) -> ContractAddress {
            AccountTrait::get_starknet_address(evm_address)
        }
    }

    /// INTERNAL-FACING FUNCTIONS ///

    // Internal-facing "ownable" functions
    impl InternalImplOwnable = OwnableComponent::InternalImpl<ContractState>;

    // Internal-facing "upgradeable" functions
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
}
