use pragma::entry::structs::{DataType, PragmaPricesResponse};

#[starknet::interface]
trait IOracle<TContractState> {
    fn get_data_median(self: @TContractState, data_type: DataType) -> PragmaPricesResponse;
}

#[starknet::interface]
trait IMockPragmaOracle<TContractState> {
    fn set_price(
        ref self: TContractState,
        pair_id: felt252,
        price: u128,
        decimals: u32,
        last_updated_timestamp: u64,
        num_sources_aggregated: u32,
    );
}

#[starknet::contract]
mod MockPragmaOracle {
    use starknet::ContractAddress;
    use pragma::entry::structs::{DataType, PragmaPricesResponse};

    use super::{IOracle, IMockPragmaOracle};

    #[storage]
    struct Storage {
        pair_id: felt252,
        price: u128,
        decimals: u32,
        last_updated_timestamp: u64,
        num_sources_aggregated: u32
    }

    //! Must be compatible with Cairo 2.2.0
    #[external(v0)]
    impl IPragmaOracleImpl of IOracle<ContractState> {
        fn get_data_median(self: @ContractState, data_type: DataType) -> PragmaPricesResponse {
            match data_type {
                DataType::SpotEntry => {
                    PragmaPricesResponse {
                        price: self.price.read(),
                        decimals: self.decimals.read(),
                        last_updated_timestamp: self.last_updated_timestamp.read(),
                        num_sources_aggregated: self.num_sources_aggregated.read(),
                        expiration_timestamp: Option::None,
                    }
                },
                DataType::FutureEntry => {
                    PragmaPricesResponse {
                        price: self.price.read(),
                        decimals: self.decimals.read(),
                        last_updated_timestamp: self.last_updated_timestamp.read(),
                        num_sources_aggregated: self.num_sources_aggregated.read(),
                        expiration_timestamp: Option::Some(
                            self.last_updated_timestamp.read() + 1000
                        ),
                    }
                },
                DataType::GenericEntry => {
                    PragmaPricesResponse {
                        price: self.price.read(),
                        decimals: self.decimals.read(),
                        last_updated_timestamp: self.last_updated_timestamp.read(),
                        num_sources_aggregated: self.num_sources_aggregated.read(),
                        expiration_timestamp: Option::None,
                    }
                }
            }
        }
    }

    #[external(v0)]
    impl IMockPragmaOracleImpl of IMockPragmaOracle<ContractState> {
        fn set_price(
            ref self: ContractState,
            pair_id: felt252,
            price: u128,
            decimals: u32,
            last_updated_timestamp: u64,
            num_sources_aggregated: u32
        ) {
            self.pair_id.write(pair_id);
            self.price.write(price);
            self.decimals.write(decimals);
            self.last_updated_timestamp.write(last_updated_timestamp);
            self.num_sources_aggregated.write(num_sources_aggregated);
        }
    }
}
