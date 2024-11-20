#[starknet::contract]
mod StarknetToken {
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::IERC20Metadata;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        decimals: u8,
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
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self._set_decimals(decimals);

        // ERC20 initialization
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, initial_supply);
    }

    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
        self.erc20._mint(to, amount);
    }

    #[abi(embed_v0)]
    impl ERC20MetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _set_decimals(ref self: ContractState, decimals: u8) {
            self.decimals.write(decimals);
        }
    }
}
