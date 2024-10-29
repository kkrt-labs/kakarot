use pragma_lib::types::{DataType, AggregationMode};

#[starknet::interface]
trait ISummaryStats<TContractState> {
    fn calculate_mean(
        self: @TContractState,
        data_type: DataType,
        start: u64,
        stop: u64,
        aggregation_mode: AggregationMode
    ) -> (u128, u32);

    fn calculate_volatility(
        self: @TContractState,
        data_type: DataType,
        start_tick: u64,
        end_tick: u64,
        num_samples: u64,
        aggregation_mode: AggregationMode
    ) -> (u128, u32);

    fn calculate_twap(
        self: @TContractState,
        data_type: DataType,
        aggregation_mode: AggregationMode,
        time: u64,
        start_time: u64,
    ) -> (u128, u32);
}

#[starknet::contract]
mod MockPragmaSummaryStats {
    use core::zeroable::Zeroable;
    use starknet::ContractAddress;
    use pragma_lib::types::{DataType, AggregationMode};
    use pragma_lib::abi::{IPragmaABIDispatcher, IPragmaABIDispatcherTrait};

    use super::ISummaryStats;

    #[storage]
    struct Storage {
        pragma_oracle: IPragmaABIDispatcher,
    }

    #[constructor]
    fn constructor(ref self: ContractState, pragma_oracle_address: ContractAddress) {
        assert(!pragma_oracle_address.is_zero(), 'Pragma Oracle cannot be 0');
        let pragma_oracle = IPragmaABIDispatcher { contract_address: pragma_oracle_address };
        self.pragma_oracle.write(pragma_oracle);
    }

    //! Must be compatible with Cairo 2.2.0
    #[external(v0)]
    impl ISummaryStatsImpl of ISummaryStats<ContractState> {
        fn calculate_mean(
            self: @ContractState,
            data_type: DataType,
            start: u64,
            stop: u64,
            aggregation_mode: AggregationMode
        ) -> (u128, u32) {
            let data = self.pragma_oracle.read().get_data(data_type, aggregation_mode);
            (data.price, data.decimals)
        }

        fn calculate_volatility(
            self: @ContractState,
            data_type: DataType,
            start_tick: u64,
            end_tick: u64,
            num_samples: u64,
            aggregation_mode: AggregationMode
        ) -> (u128, u32) {
            let data = self.pragma_oracle.read().get_data(data_type, aggregation_mode);
            (data.price, data.decimals)
        }

        fn calculate_twap(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            time: u64,
            start_time: u64,
        ) -> (u128, u32) {
            let data = self.pragma_oracle.read().get_data(data_type, aggregation_mode);
            (data.price, data.decimals)
        }
    }
}
