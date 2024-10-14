use pragma::entry::structs::{DataType, AggregationMode};

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

#[starknet::interface]
trait IMockSummaryStats<TContractState> {
    fn set_result(ref self: TContractState, pair_id: felt252, price: u128, decimals: u32,);
}

#[starknet::contract]
mod MockSummaryStats {
    use starknet::ContractAddress;
    use pragma::entry::structs::{DataType, AggregationMode};

    use super::{ISummaryStats, IMockSummaryStats};

    #[storage]
    struct Storage {
        pair_id: felt252,
        price: u128,
        decimals: u32,
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
            (self.price.read(), self.decimals.read())
        }

        fn calculate_volatility(
            self: @ContractState,
            data_type: DataType,
            start_tick: u64,
            end_tick: u64,
            num_samples: u64,
            aggregation_mode: AggregationMode
        ) -> (u128, u32) {
            (self.price.read(), self.decimals.read())
        }

        fn calculate_twap(
            self: @ContractState,
            data_type: DataType,
            aggregation_mode: AggregationMode,
            time: u64,
            start_time: u64,
        ) -> (u128, u32) {
            (self.price.read(), self.decimals.read())
        }
    }

    #[external(v0)]
    impl IMockSummaryStatsImpl of IMockSummaryStats<ContractState> {
        fn set_result(ref self: ContractState, pair_id: felt252, price: u128, decimals: u32,) {
            self.pair_id.write(pair_id);
            self.price.write(price);
            self.decimals.write(decimals);
        }
    }
}
