use starknet::{ContractAddress, ClassHash};

#[starknet::interface]
pub trait IKakarot<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn set_base_fee(ref self: TContractState, new_base_fee: felt252);
}
