use core::starknet::{get_caller_address, ContractAddress};


#[starknet::interface]
pub trait IERC20<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
}

#[starknet::contract]
pub mod BalanceSender {
    use core::starknet::{get_caller_address, ContractAddress, ClassHash, get_contract_address, SyscallResult};
    use super::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::starknet::syscalls::{replace_class_syscall};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn send_balance(self: @ContractState, token_address: ContractAddress, recipient: ContractAddress) -> bool {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
        let balance = erc20_dispatcher.balance_of(get_contract_address());
        erc20_dispatcher.transfer(recipient, balance)
    }

    #[external(v0)]
    fn replace_class(ref self: ContractState, new_class: ClassHash) -> SyscallResult<()>{
        replace_class_syscall(new_class)
    }
}
