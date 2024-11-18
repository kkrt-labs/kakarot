//! A non-standard implementation of the ERC20 Token on Starknet.
//! Used for testing purposes with the DualVMToken.
//! Applied the following changes:
//! - `transfer` and `transfer_from` always return false
//! - `approve` always returns false
//! - `name`, `symbol` return a felt instead of a ByteArray

#[starknet::interface]
trait IERC20FeltMetadata<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
}


#[starknet::contract]
mod NonStandardStarknetToken {
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::{IERC20};
    use super::IERC20FeltMetadata;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        decimals: u8,
        name: felt252,
        symbol: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self._set_decimals(decimals);

        // ERC20 initialization
        self.name.write(name);
        self.symbol.write(symbol);
        self.erc20._mint(recipient, initial_supply);
    }

    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
        self.erc20._mint(to, amount);
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20FeltMetadata<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    #[abi(embed_v0)]
    impl ERC20 of IERC20<ContractState> {
        /// Returns the value of tokens in existence.
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.ERC20_total_supply.read()
        }

        /// Returns the amount of tokens owned by `account`.
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.ERC20_balances.read(account)
        }

        /// Returns the remaining number of tokens that `spender` is
        /// allowed to spend on behalf of `owner` through `transfer_from`.
        /// This is zero by default.
        /// This value changes when `approve` or `transfer_from` are called.
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.erc20.ERC20_allowances.read((owner, spender))
        }


        /// Modified to always return false
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            false
        }


        /// Modified to always return false
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            false
        }

        /// Modified to always return false
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            false
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _set_decimals(ref self: ContractState, decimals: u8) {
            self.decimals.write(decimals);
        }
    }
}
