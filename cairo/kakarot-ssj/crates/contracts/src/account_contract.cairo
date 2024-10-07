//! The generic account that is deployed by Kakarot Core before being "specialized" into an
//! Externally Owned Account or a Contract Account This aims at having only one class hash for all
//! the contracts deployed by Kakarot, thus enforcing a unique and consistent address mapping Eth
//! Address <=> Starknet Address

use core::starknet::account::{Call};
use core::starknet::{EthAddress, ClassHash, ContractAddress};

#[derive(Copy, Drop, Serde, Debug)]
pub struct OutsideExecution {
    pub caller: ContractAddress,
    pub nonce: u64,
    pub execute_after: u64,
    pub execute_before: u64,
    pub calls: Span<Call>
}

#[starknet::interface]
pub trait IAccount<TContractState> {
    fn initialize(
        ref self: TContractState, evm_address: EthAddress, implementation_class: ClassHash
    );
    fn get_implementation(self: @TContractState) -> ClassHash;
    fn get_evm_address(self: @TContractState) -> EthAddress;
    fn get_code_hash(self: @TContractState) -> u256;
    fn set_code_hash(ref self: TContractState, code_hash: u256);
    fn is_initialized(self: @TContractState) -> bool;

    // EOA functions
    fn __validate__(ref self: TContractState, calls: Array<Call>) -> felt252;
    fn __validate_declare__(self: @TContractState, class_hash: felt252) -> felt252;
    fn __execute__(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;

    // CA functions
    fn write_bytecode(ref self: TContractState, bytecode: Span<u8>);
    fn bytecode(self: @TContractState) -> Span<u8>;
    fn write_storage(ref self: TContractState, key: u256, value: u256);
    fn storage(self: @TContractState, key: u256) -> u256;
    fn get_nonce(self: @TContractState) -> u64;
    fn set_nonce(ref self: TContractState, nonce: u64);
    fn execute_starknet_call(ref self: TContractState, call: Call) -> (bool, Span<felt252>);
    fn execute_from_outside(
        ref self: TContractState, outside_execution: OutsideExecution, signature: Span<felt252>,
    ) -> Array<Span<felt252>>;
}

#[starknet::contract(account)]
pub mod AccountContract {
    use core::cmp::min;
    use core::num::traits::Bounded;
    use core::num::traits::zero::Zero;
    use core::starknet::account::{Call};
    use core::starknet::eth_signature::verify_eth_signature;
    use core::starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };
    use core::starknet::syscalls::call_contract_syscall;
    use core::starknet::{
        EthAddress, ClassHash, get_caller_address, get_tx_info, get_block_timestamp
    };
    use crate::components::ownable::IOwnable;
    use crate::components::ownable::ownable_component::InternalTrait;
    use crate::components::ownable::ownable_component;
    use crate::errors::KAKAROT_REENTRANCY;
    use crate::kakarot_core::eth_rpc::{IEthRPCDispatcher, IEthRPCDispatcherTrait};
    use crate::kakarot_core::interface::{IKakarotCoreDispatcher, IKakarotCoreDispatcherTrait};
    use crate::storage::StorageBytecode;
    use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
    use super::OutsideExecution;
    use utils::eth_transaction::transaction::TransactionTrait;
    use utils::serialization::{deserialize_signature, deserialize_bytes, serialize_bytes};
    use utils::traits::DefaultSignature;

    // Add ownable component
    component!(path: ownable_component, storage: ownable, event: OwnableEvent);
    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;
    impl OwnableInternal = ownable_component::InternalImpl<ContractState>;


    const VERSION: u32 = 000_001_000;


    #[storage]
    pub(crate) struct Storage {
        pub(crate) Account_bytecode: StorageBytecode,
        pub(crate) Account_bytecode_len: u32,
        pub(crate) Account_storage: Map<u256, u256>,
        pub(crate) Account_is_initialized: bool,
        pub(crate) Account_nonce: u64,
        pub(crate) Account_implementation: ClassHash,
        pub(crate) Account_evm_address: EthAddress,
        pub(crate) Account_code_hash: u256,
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        transaction_executed: TransactionExecuted,
        OwnableEvent: ownable_component::Event
    }

    #[derive(Drop, starknet::Event, Debug)]
    pub struct TransactionExecuted {
        pub response: Span<felt252>,
        pub success: bool,
        pub gas_used: u64
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        panic!("Accounts cannot be created directly");
    }

    #[abi(embed_v0)]
    impl Account of super::IAccount<ContractState> {
        fn initialize(
            ref self: ContractState, evm_address: EthAddress, implementation_class: ClassHash
        ) {
            assert(!self.Account_is_initialized.read(), 'Account already initialized');
            self.Account_is_initialized.write(true);

            self.Account_evm_address.write(evm_address);
            self.Account_implementation.write(implementation_class);

            let kakarot_address = self.ownable.owner();
            let kakarot = IKakarotCoreDispatcher { contract_address: kakarot_address };
            let native_token = kakarot.get_native_token();
            // To internally perform value transfer of the network's native
            // token (which conforms to the ERC20 standard), we need to give the
            // KakarotCore contract infinite allowance
            IERC20CamelDispatcher { contract_address: native_token }
                .approve(kakarot_address, Bounded::<u256>::MAX);

            kakarot.register_account(evm_address);
        }

        fn get_implementation(self: @ContractState) -> ClassHash {
            self.Account_implementation.read()
        }

        fn get_evm_address(self: @ContractState) -> EthAddress {
            self.Account_evm_address.read()
        }

        fn get_code_hash(self: @ContractState) -> u256 {
            self.Account_code_hash.read()
        }

        fn set_code_hash(ref self: ContractState, code_hash: u256) {
            self.ownable.assert_only_owner();
            self.Account_code_hash.write(code_hash);
        }

        fn is_initialized(self: @ContractState) -> bool {
            self.Account_is_initialized.read()
        }

        // EOA functions
        fn __validate__(ref self: ContractState, calls: Array<Call>) -> felt252 {
            panic!("EOA: __validate__ not supported")
        }

        /// Validate Declare is not used for Kakarot
        fn __validate_declare__(self: @ContractState, class_hash: felt252) -> felt252 {
            panic!("EOA: declare not supported")
        }

        fn __execute__(ref self: ContractState, calls: Array<Call>) -> Array<Span<felt252>> {
            panic!("EOA: __execute__ not supported")
        }

        fn write_bytecode(ref self: ContractState, bytecode: Span<u8>) {
            self.ownable.assert_only_owner();
            self.Account_bytecode.write(StorageBytecode { bytecode });
        }

        fn bytecode(self: @ContractState) -> Span<u8> {
            self.Account_bytecode.read().bytecode
        }

        fn write_storage(ref self: ContractState, key: u256, value: u256) {
            self.ownable.assert_only_owner();
            self.Account_storage.write(key, value);
        }

        fn storage(self: @ContractState, key: u256) -> u256 {
            self.Account_storage.read(key)
        }

        fn get_nonce(self: @ContractState) -> u64 {
            self.Account_nonce.read()
        }

        fn set_nonce(ref self: ContractState, nonce: u64) {
            self.ownable.assert_only_owner();
            self.Account_nonce.write(nonce);
        }

        /// Used to preserve caller in Cairo Precompiles
        /// Reentrency check is done for Kakarot contract, only get_starknet_address is allowed
        /// for Solidity contracts to be able to get the corresponding Starknet address in their
        /// calldata.
        fn execute_starknet_call(ref self: ContractState, call: Call) -> (bool, Span<felt252>) {
            self.ownable.assert_only_owner();
            let kakarot_address = self.ownable.owner();
            if call.to == kakarot_address && call.selector != selector!("get_starknet_address") {
                return (false, KAKAROT_REENTRANCY.span());
            }
            let response = call_contract_syscall(call.to, call.selector, call.calldata);
            if response.is_ok() {
                return (true, response.unwrap().into());
            }
            return (false, response.unwrap_err().into());
        }

        fn execute_from_outside(
            ref self: ContractState, outside_execution: OutsideExecution, signature: Span<felt252>,
        ) -> Array<Span<felt252>> {
            let caller = get_caller_address();
            let tx_info = get_tx_info();

            // SNIP-9 Validation
            if (outside_execution.caller.into() != 'ANY_CALLER') {
                assert(caller == outside_execution.caller, 'SNIP9: Invalid caller');
            }

            let block_timestamp = get_block_timestamp();
            assert(block_timestamp > outside_execution.execute_after, 'SNIP9: Too early call');
            assert(block_timestamp < outside_execution.execute_before, 'SNIP9: Too late call');

            // Kakarot-Specific Validation
            assert(outside_execution.calls.len() == 1, 'KKRT: Multicall not supported');
            assert(tx_info.version.into() >= 1_u256, 'KKRT: Deprecated tx version: 0');

            // EOA Validation
            assert(self.Account_bytecode_len.read().is_zero(), 'EOA: cannot have code');

            let kakarot = IEthRPCDispatcher { contract_address: self.ownable.owner() };

            let chain_id: u64 = kakarot.eth_chain_id();
            assert(signature.len() == 5, 'EOA: Invalid signature length');
            let signature = deserialize_signature(signature, chain_id)
                .expect('EOA: invalid signature');

            let mut encoded_tx_data = deserialize_bytes((*outside_execution.calls[0]).calldata)
                .expect('conversion to Span<u8> failed')
                .span();
            let unsigned_transaction_hash = TransactionTrait::compute_hash(encoded_tx_data);

            let address = self.Account_evm_address.read();
            verify_eth_signature(unsigned_transaction_hash, signature, address);

            let (success, return_data, gas_used) = kakarot
                .eth_send_raw_unsigned_tx(encoded_tx_data);
            let return_data = serialize_bytes(return_data).span();

            // See Argent account
            // https://github.com/argentlabs/argent-contracts-starknet/blob/1352198956f36fb35fa544c4e46a3507a3ec20e3/src/presets/user_account.cairo#L211-L213
            // See 300 max data_len for events
            // https://github.com/starkware-libs/blockifier/blob/9bfb3d4c8bf1b68a0c744d1249b32747c75a4d87/crates/blockifier/resources/versioned_constants.json
            // The whole data_len should be less than 300, so it's the return_data should be less
            // than 297 (+3 for return_data_len, success, gas_used)
            self
                .emit(
                    TransactionExecuted {
                        response: return_data.slice(0, min(297, return_data.len())),
                        success: success,
                        gas_used
                    }
                );
            array![return_data]
        }
    }
}
