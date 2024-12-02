use starknet::account::Call;
use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IProtocolHandler<TContractState> {
    /// Execute a call to the Kakarot contract.
    /// Only the security council can call this function.
    /// # Arguments
    /// * `call` - The call to be executed
    ///
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the security council
    /// * `ONLY_KAKAROT_CAN_BE_CALLED` in case the call is not to the Kakarot contract
    ///
    fn emergency_execution(ref self: TContractState, call: Call);

    /// Upgrade the Kakarot contract to a new version.
    /// Only the operator can call this function.
    /// # Arguments
    /// * `new_class_hash` - The new class hash of the Kakarot contract
    ///
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the operator
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    /// Transfer the ownership of the Kakarot contract.
    /// Only the security council can call this function.
    /// # Arguments
    /// * `new_owner` - The new owner of the Kakarot contract
    ///
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the security council
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);

    /// Pause the protocol for SOFT_PAUSE_DELAY.
    /// Only the guardians can call this function.
    /// # Panics
    /// * `Caller is missing role` in case the caller is not a guardian
    fn soft_pause(ref self: TContractState);

    /// Pause the protocol for HARD_PAUSE_DELAY.
    /// Only the security council can call this function.
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the security council
    fn hard_pause(ref self: TContractState);

    /// Unpause the protocol.
    /// Only the security council can call this function if the delay is not passed.
    /// Else anyone can call this function.
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the security council
    fn unpause(ref self: TContractState);

    /// Set the base fee of the Kakarot contract.
    /// Only the gas price admin can call this function.
    /// # Arguments
    /// * `base_fee` - The new base fee
    ///
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the gas price admin
    fn set_base_fee(ref self: TContractState, new_base_fee: felt252);

    /// Execute a call to the Kakarot contract
    /// Only the operator can call this function.
    /// # Arguments
    /// * `call` - The call to be executed
    ///
    /// # Panics
    /// * `Caller is missing role` in case the caller is not the operator
    /// * `UNAUTHORIZED_SELECTOR` in case the selector is not authorized
    /// * `ONLY_KAKAROT_CAN_BE_CALLED` in case the call is not to the Kakarot contract
    fn execute_call(ref self: TContractState, call: Call);
}

#[starknet::contract]
pub mod ProtocolHandler {
    use starknet::event::EventEmitter;
    use starknet::account::Call;
    use starknet::{ContractAddress, ClassHash, get_block_timestamp, SyscallResultTrait};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess,
        StorageMapWriteAccess
    };
    use openzeppelin_access::accesscontrol::AccessControlComponent;
    use openzeppelin_introspection::src5::SRC5Component;
    use crate::kakarot_interface::{IKakarotDispatcher, IKakarotDispatcherTrait};

    //* ------------------------------------------------------------------------ *//
    //*                                COMPONENTS                                *//
    //* ------------------------------------------------------------------------ *//

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;


    //* ------------------------------------------------------------------------ *//
    //*                                 CONSTANTS                                *//
    //* ------------------------------------------------------------------------ *//

    // Access controls roles
    const SECURITY_COUNCIL_ROLE: felt252 = selector!("SECURITY_COUNCIL_ROLE");
    const OPERATOR_ROLE: felt252 = selector!("OPERATOR_ROLE");
    const GUARDIAN_ROLE: felt252 = selector!("GUARDIAN_ROLE");
    const GAS_PRICE_ADMIN_ROLE: felt252 = selector!("GAS_PRICE_ADMIN_ROLE");
    // Pause delay
    pub const SOFT_PAUSE_DELAY: u64 = 12 * 60 * 60; // 12 hours
    pub const HARD_PAUSE_DELAY: u64 = 7 * 24 * 60 * 60; // 7 days


    //* ------------------------------------------------------------------------ *//
    //*                                  ERRORS                                  *//
    //* ------------------------------------------------------------------------ *//

    pub mod errors {
        pub const ONLY_KAKAROT_CAN_BE_CALLED: felt252 = 'ONLY_KAKAROT_CAN_BE_CALLED';
        pub const PROTOCOL_ALREADY_PAUSED: felt252 = 'PROTOCOL_ALREADY_PAUSED';
        pub const UNAUTHORIZED_SELECTOR: felt252 = 'UNAUTHORIZED_SELECTOR';
    }

    //* ------------------------------------------------------------------------ *//
    //*                                  STORAGE                                 *//
    //* ------------------------------------------------------------------------ *//

    #[storage]
    pub struct Storage {
        pub kakarot: IKakarotDispatcher,
        pub operator: ContractAddress,
        pub guardians: Map<ContractAddress, bool>,
        pub gas_price_admin: ContractAddress,
        pub protocol_frozen_until: u64,
        pub authorized_operator_selector: Map<felt252, bool>,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    //* ------------------------------------------------------------------------ *//
    //*                                  EVENTS                                  *//
    //* ------------------------------------------------------------------------ *//

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        EmergencyExecution: EmergencyExecution,
        Upgrade: Upgrade,
        TransferOwnership: TransferOwnership,
        SoftPause: SoftPause,
        HardPause: HardPause,
        Unpause: Unpause,
        BaseFeeChanged: BaseFeeChanged,
        Execution: Execution,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyExecution {
        pub call: Call
    }

    #[derive(Drop, starknet::Event)]
    pub struct Upgrade {
        pub new_class_hash: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferOwnership {
        pub new_owner: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct SoftPause {
        pub protocol_frozen_until: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct HardPause {
        pub protocol_frozen_until: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpause {}

    #[derive(Drop, starknet::Event)]
    pub struct BaseFeeChanged {
        pub new_base_fee: felt252
    }

    #[derive(Drop, starknet::Event)]
    pub struct Execution {
        pub call: Call
    }

    //* ------------------------------------------------------------------------ *//
    //*                                CONSTRUCTOR                               *//
    //* ------------------------------------------------------------------------ *//

    #[constructor]
    fn constructor(
        ref self: ContractState,
        kakarot: ContractAddress,
        security_council: ContractAddress,
        operator: ContractAddress,
        gas_price_admin: ContractAddress,
        mut guardians: Span<ContractAddress>
    ) {
        // Store the Kakarot address
        self.kakarot.write(IKakarotDispatcher { contract_address: kakarot });

        // AccessControl-related initialization
        self.accesscontrol.initializer();

        // Grant roles
        self.accesscontrol._grant_role(SECURITY_COUNCIL_ROLE, security_council);
        self.accesscontrol._grant_role(OPERATOR_ROLE, operator);
        for guardian in guardians {
            self.accesscontrol._grant_role(GUARDIAN_ROLE, *guardian);
        };
        self.accesscontrol._grant_role(GAS_PRICE_ADMIN_ROLE, gas_price_admin);

        // Store the authorized selectors for the operator
        self.authorized_operator_selector.write(selector!("set_native_token"), true);
        self.authorized_operator_selector.write(selector!("set_coinbase"), true);
        self.authorized_operator_selector.write(selector!("set_prev_randao"), true);
        self.authorized_operator_selector.write(selector!("set_block_gas_limit"), true);
        self.authorized_operator_selector.write(selector!("set_account_contract_class_hash"), true);
        self
            .authorized_operator_selector
            .write(selector!("set_uninitialized_account_class_hash"), true);
        self
            .authorized_operator_selector
            .write(selector!("set_authorized_cairo_precompile_caller"), true);
        self.authorized_operator_selector.write(selector!("set_cairo1_helpers_class_hash"), true);
        self.authorized_operator_selector.write(selector!("upgrade_account"), true);
        self.authorized_operator_selector.write(selector!("set_authorized_pre_eip155_tx"), true);
        self
            .authorized_operator_selector
            .write(selector!("set_l1_messaging_contract_address"), true);
    }

    #[abi(embed_v0)]
    impl ProtocolHandler of super::IProtocolHandler<ContractState> {
        //* ------------------------------------------------------------------------ *//
        //*                              ADMIN FUNCTIONS                             *//
        //* ------------------------------------------------------------------------ *//

        fn emergency_execution(ref self: ContractState, call: Call) {
            // Check only security council can call
            self.accesscontrol.assert_only_role(SECURITY_COUNCIL_ROLE);

            // Check if the call is to the Kakarot contract
            let kakarot = self.kakarot.read().contract_address;
            let Call { to, selector, calldata } = call;
            assert(to == kakarot, errors::ONLY_KAKAROT_CAN_BE_CALLED);

            // Call Kakarot with syscall
            starknet::syscalls::call_contract_syscall(to, selector, calldata).unwrap_syscall();

            // Emit EmergencyExecution event
            self.emit(EmergencyExecution { call });
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // Check only operator can call
            self.accesscontrol.assert_only_role(OPERATOR_ROLE);

            // Call the Kakarot upgrade function
            let kakarot = self.kakarot.read();
            kakarot.upgrade(new_class_hash);

            // Emit Upgrade event
            self.emit(Upgrade { new_class_hash });
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            // Check only security council can call
            self.accesscontrol.assert_only_role(SECURITY_COUNCIL_ROLE);

            // Call the Kakarot transfer_ownership function
            let kakarot = self.kakarot.read();
            kakarot.transfer_ownership(new_owner);

            // Emit TransferOwnership event
            self.emit(TransferOwnership { new_owner });
        }

        fn soft_pause(ref self: ContractState) {
            // Check only guardians can call
            self.accesscontrol.assert_only_role(GUARDIAN_ROLE);

            // Check if the protocol is already paused
            let protocol_frozen_until = self.protocol_frozen_until.read();
            assert(protocol_frozen_until == 0, errors::PROTOCOL_ALREADY_PAUSED);

            // Cache the protocol frozen until timestamp
            let protocol_frozen_until = get_block_timestamp().into() + SOFT_PAUSE_DELAY;

            // Update storage
            self.protocol_frozen_until.write(protocol_frozen_until);

            // Call the Kakarot pause function
            let kakarot = self.kakarot.read();
            kakarot.pause();

            // Emit SoftPause event
            self.emit(SoftPause { protocol_frozen_until: protocol_frozen_until });
        }

        fn hard_pause(ref self: ContractState) {
            // Check only security council can call
            self.accesscontrol.assert_only_role(SECURITY_COUNCIL_ROLE);

            // Cache the protocol frozen until timestamp
            let protocol_frozen_until = get_block_timestamp().into() + HARD_PAUSE_DELAY;

            // Update storage
            self.protocol_frozen_until.write(protocol_frozen_until);

            // Call the Kakarot pause function
            let kakarot = self.kakarot.read();
            kakarot.pause();

            // Emit HardPause event
            self.emit(HardPause { protocol_frozen_until: protocol_frozen_until });
        }

        fn unpause(ref self: ContractState) {
            // Check only security council can call unpause if delay is not passed
            let too_soon = get_block_timestamp().into() < self.protocol_frozen_until.read();
            if too_soon {
                self.accesscontrol.assert_only_role(SECURITY_COUNCIL_ROLE);
            }

            // Call the Kakarot unpause function
            let kakarot = self.kakarot.read();
            kakarot.unpause();

            // Update storage
            self.protocol_frozen_until.write(0);

            // Emit Unpause event
            self.emit(Unpause {});
        }

        fn set_base_fee(ref self: ContractState, new_base_fee: felt252) {
            // Check only gas price admin can call
            self.accesscontrol.assert_only_role(GAS_PRICE_ADMIN_ROLE);

            // Call the Kakarot set_base_fee function
            let kakarot = self.kakarot.read();
            kakarot.set_base_fee(new_base_fee);

            // Emit BaseFeeChanged
            self.emit(BaseFeeChanged { new_base_fee });
        }

        //* ------------------------------------------------------------------------ *//
        //*                           EXECUTE OPERATOR CALL                          *//
        //* ------------------------------------------------------------------------ *//

        fn execute_call(ref self: ContractState, call: Call) {
            // Check only operator can call
            self.accesscontrol.assert_only_role(OPERATOR_ROLE);

            // Ensure the selector to call is part of the authorized selectors
            let authorized = self.authorized_operator_selector.read(call.selector);
            assert(authorized, errors::UNAUTHORIZED_SELECTOR);

            // Ensure the call is to the Kakarot
            let kakarot = self.kakarot.read();
            assert(call.to == kakarot.contract_address, errors::ONLY_KAKAROT_CAN_BE_CALLED);

            // Call Kakarot with syscall
            starknet::syscalls::call_contract_syscall(call.to, call.selector, call.calldata)
                .unwrap_syscall();

            // Emit Event Execution event
            self.emit(Execution { call });
        }
    }
}
