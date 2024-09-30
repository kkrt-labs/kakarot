use core::starknet::{ContractAddress, EthAddress, ClassHash};
use utils::eth_transaction::transaction::Transaction;

#[starknet::interface]
pub trait IKakarotCore<TContractState> {
    /// Sets the native token, this token will be considered the native coin in the Ethereum sense
    fn set_native_token(ref self: TContractState, native_token: ContractAddress);

    /// Gets the native token used by the Kakarot smart contract
    fn get_native_token(self: @TContractState) -> ContractAddress;

    /// Deterministically computes a Starknet address for an given EVM address
    /// The address is computed as the Starknet address corresponding to the deployment of an EOA,
    /// Using its EVM address as salt, and KakarotCore as deployer.
    fn compute_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Checks into KakarotCore storage if an EOA or a CA has been deployed for
    /// a particular EVM address and. If so returns its corresponding address,
    /// otherwise returns 0
    fn address_registry(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Deploys an EOA for a particular EVM address
    fn deploy_externally_owned_account(
        ref self: TContractState, evm_address: EthAddress
    ) -> ContractAddress;

    /// Upgrade the KakarotCore smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    // Setter for the Account Class Hash
    fn set_account_contract_class_hash(ref self: TContractState, new_class_hash: ClassHash);
    fn get_account_contract_class_hash(self: @TContractState) -> ClassHash;

    // Getter for the Generic Account Class
    fn uninitialized_account_class_hash(self: @TContractState) -> ClassHash;
    // Setter for the Generic Account Class
    fn set_account_class_hash(ref self: TContractState, new_class_hash: ClassHash);

    fn register_account(ref self: TContractState, evm_address: EthAddress);

    // Getter for the Block Gas Limit
    fn get_block_gas_limit(self: @TContractState) -> u64;

    // Getter for the Base Fee
    fn get_base_fee(self: @TContractState) -> u64;
    /// Setter for the base fee
    fn set_base_fee(ref self: TContractState, base_fee: u64);

    // Getter for the Starknet Address
    fn get_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;
}

#[starknet::interface]
pub trait IExtendedKakarotCore<TContractState> {
    /// Sets the native token, this token will be considered the native coin in the Ethereum sense
    fn set_native_token(ref self: TContractState, native_token: ContractAddress);

    /// Gets the native token used by the Kakarot smart contract
    fn get_native_token(self: @TContractState) -> ContractAddress;

    /// Deterministically computes a Starknet address for an given EVM address
    /// The address is computed as the Starknet address corresponding to the deployment of an EOA,
    /// Using its EVM address as salt, and KakarotCore as deployer.
    fn compute_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Checks into KakarotCore storage if an EOA or a CA has been deployed for
    /// a particular EVM address and. If so returns its corresponding address,
    /// otherwise returns 0
    fn address_registry(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    /// Deploys an EOA for a particular EVM address
    fn deploy_externally_owned_account(
        ref self: TContractState, evm_address: EthAddress
    ) -> ContractAddress;

    /// Returns the balance of the specified address.
    fn eth_get_balance(self: @TContractState, address: EthAddress) -> u256;

    /// View entrypoint into the EVM
    /// Performs view calls into the blockchain
    /// It cannot modify the state of the chain
    fn eth_call(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64);

    /// Transaction entrypoint into the EVM
    /// Executes an EVM transaction and possibly modifies the state
    fn eth_send_transaction(ref self: TContractState, tx: Transaction) -> (bool, Span<u8>, u64);

    // Returns the transaction count (nonce) of the specified address
    fn eth_get_transaction_count(self: @TContractState, address: EthAddress) -> u64;

    /// Upgrade the KakarotCore smart contract
    /// Using replace_class_syscall
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);

    // Setter for the Account Class Hash
    fn set_account_contract_class_hash(ref self: TContractState, new_class_hash: ClassHash);
    fn get_account_contract_class_hash(self: @TContractState) -> ClassHash;

    // Getter for the Generic Account Class
    fn uninitialized_account_class_hash(self: @TContractState) -> ClassHash;
    // Setter for the Generic Account Class
    fn set_account_class_hash(ref self: TContractState, new_class_hash: ClassHash);

    fn register_account(ref self: TContractState, evm_address: EthAddress);

    // Getter for the Block Gas Limit
    fn get_block_gas_limit(self: @TContractState) -> u64;
    // Getter for the Base Fee
    fn get_base_fee(self: @TContractState) -> u64;
    /// Setter for the base fee
    fn set_base_fee(ref self: TContractState, base_fee: u64);

    // Getter for the Starknet Address
    fn get_starknet_address(self: @TContractState, evm_address: EthAddress) -> ContractAddress;

    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}
