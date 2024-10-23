use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IKakarot<TContractState> {
    //* ------------------------------------------------------------------------ *//
    //*                              ADMIN FUNCTIONS                             *//
    //* ------------------------------------------------------------------------ *//
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);

    //* ------------------------------------------------------------------------ *//
    //*                         STORAGE SETTING FUNCTIONS                        *//
    //* ------------------------------------------------------------------------ *//
    fn set_native_token(ref self: TContractState, native_token: ContractAddress);
    fn set_base_fee(ref self: TContractState, base_fee: u64);
    fn set_coinbase(ref self: TContractState, new_coinbase: ContractAddress);
    fn set_prev_randao(ref self: TContractState, pre_randao: felt252);
    fn set_block_gas_limit(ref self: TContractState, new_block_gas_limit: felt252);
    fn set_account_contract_class_hash(ref self: TContractState, new_class_hash: felt252);
    fn set_uninitialized_account_class_hash(ref self: TContractState, new_class_hash: felt252);
    fn set_authorized_cairo_precompile_caller(
        ref self: TContractState, evm_address: ContractAddress, authorized: bool
    );
    fn set_cairo1_helpers_class_hash(ref self: TContractState, new_class_hash: felt252);
    fn upgrade_account(ref self: TContractState, evm_address: ContractAddress, new_class: felt252);
    fn set_authorized_pre_eip155_tx(
        ref self: TContractState, sender_address: ContractAddress, msg_hash: felt252
    );
    fn set_l1_messaging_contract_address(
        ref self: TContractState, l1_messaging_contract_address: ContractAddress
    );
}
