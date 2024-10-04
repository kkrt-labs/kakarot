mod contracts;

#[cfg(target: 'test')]
pub mod snforge_utils {
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use evm::state::compute_storage_key;
    use starknet::ContractAddress;
    use evm::model::Address;
    use snforge_std::cheatcodes::storage::store_felt252;
    use snforge_std::Event;
    use snforge_std::cheatcodes::events::{Events};
    use array_utils::ArrayExtTrait;

    use snforge_std::trace::{get_call_trace, CallTrace, CallEntryPoint};

    pub fn is_called(contract_address: ContractAddress, selector: felt252) -> bool {
        let call_trace = get_call_trace();

        // Check if the top-level call matches
        if check_call_match(call_trace.entry_point, contract_address, selector) {
            return true;
        }

        // Check nested calls recursively
        if check_nested_calls(call_trace.nested_calls, contract_address, selector) {
            return true;
        }

        false
    }

    pub fn assert_called(contract_address: ContractAddress, selector: felt252) {
        assert!(is_called(contract_address, selector), "Expected call not found in trace");
    }

    pub fn assert_not_called(contract_address: ContractAddress, selector: felt252) {
        assert!(!is_called(contract_address, selector), "Unexpected call found in trace");
    }

    fn check_call_match(
        entry_point: CallEntryPoint, contract_address: ContractAddress, selector: felt252
    ) -> bool {
        entry_point.contract_address == contract_address
            && entry_point.entry_point_selector == selector
    }

    fn check_nested_calls(
        calls: Array<CallTrace>, contract_address: ContractAddress, selector: felt252
    ) -> bool {
        let mut i = 0;
        loop {
            if i == calls.len() {
                break false;
            }
            let call = calls.at(i).clone();
            if check_call_match(call.entry_point, contract_address, selector) {
                break true;
            }
            if check_nested_calls(call.nested_calls, contract_address, selector) {
                break true;
            }
            i += 1;
        }
    }

    pub fn assert_called_with<C, +Serde<C>, +Drop<C>, +Copy<C>>(
        contract_address: ContractAddress, selector: felt252, calldata: C
    ) {
        let mut serialized_calldata = array![];
        Serde::serialize(@calldata, ref serialized_calldata);
        assert!(
            is_called_with(contract_address, selector, serialized_calldata.span()),
            "Expected call with specific data not found in trace"
        );
    }


    pub fn is_called_with(
        contract_address: ContractAddress, selector: felt252, calldata: Span<felt252>
    ) -> bool {
        let call_trace = get_call_trace();

        if check_call_match_with_data(
            call_trace.entry_point, contract_address, selector, calldata
        ) {
            return true;
        }

        check_nested_calls_with_data(call_trace.nested_calls, contract_address, selector, calldata)
    }


    fn check_call_match_with_data(
        call: CallEntryPoint,
        contract_address: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>
    ) -> bool {
        call.contract_address == contract_address
            && call.entry_point_selector == selector
            && call.calldata.span() == calldata
    }

    fn check_nested_calls_with_data(
        calls: Array<CallTrace>,
        contract_address: ContractAddress,
        selector: felt252,
        calldata: Span<felt252>
    ) -> bool {
        let mut i = 0;
        loop {
            if i == calls.len() {
                break false;
            }
            let call = calls.at(i).clone();
            if check_call_match_with_data(call.entry_point, contract_address, selector, calldata) {
                break true;
            }
            if check_nested_calls_with_data(
                call.nested_calls, contract_address, selector, calldata
            ) {
                break true;
            }
            i += 1;
        }
    }

    mod array_utils {
        #[generate_trait]
        pub impl ArrayExtImpl<T, +Copy<T>, +Drop<T>> of ArrayExtTrait<T> {
            fn includes<+PartialEq<T>>(self: @Array<T>, item: T) -> bool {
                let mut i = 0;
                let mut found = false;
                found =
                    loop {
                        if i == self.len() {
                            break false;
                        };
                        if (*self.at(i)) == item {
                            break true;
                        }
                        i += 1;
                    };
                return found;
            }
        }
    }

    /// A wrapper structure on an array of events emitted by a given contract.
    #[derive(Drop, Clone)]
    pub struct ContractEvents {
        pub events: Span<Event>
    }

    pub trait EventsFilterTrait {
        fn emitted_by(self: @Events, contract_address: ContractAddress) -> EventsFilter;
    }

    impl EventsFilterTraitImpl of EventsFilterTrait {
        fn emitted_by(self: @Events, contract_address: ContractAddress) -> EventsFilter {
            EventsFilter {
                events: self,
                contract_address: Option::Some(contract_address),
                key_filter: Option::None,
                data_filter: Option::None,
            }
        }
    }

    #[derive(Copy, Drop)]
    pub struct EventsFilter {
        events: @Events,
        contract_address: Option<ContractAddress>,
        key_filter: Option<Span<felt252>>,
        data_filter: Option<felt252>,
    }

    pub trait EventsFilterBuilderTrait {
        fn from_events(events: @Events) -> EventsFilter;
        fn with_contract_address(
            self: EventsFilter, contract_address: ContractAddress
        ) -> EventsFilter;
        fn with_keys(self: EventsFilter, keys: Span<felt252>) -> EventsFilter;
        fn with_data(self: EventsFilter, data: felt252) -> EventsFilter;
        fn build(self: @EventsFilter) -> ContractEvents;
    }

    impl EventsFilterBuilderTraitImpl of EventsFilterBuilderTrait {
        fn from_events(events: @Events) -> EventsFilter {
            EventsFilter {
                events: events,
                contract_address: Option::None,
                key_filter: Option::None,
                data_filter: Option::None,
            }
        }

        fn with_contract_address(
            mut self: EventsFilter, contract_address: ContractAddress
        ) -> EventsFilter {
            self.contract_address = Option::Some(contract_address);
            self
        }

        fn with_keys(mut self: EventsFilter, keys: Span<felt252>) -> EventsFilter {
            self.key_filter = Option::Some(keys);
            self
        }

        fn with_data(mut self: EventsFilter, data: felt252) -> EventsFilter {
            self.data_filter = Option::Some(data);
            self
        }

        fn build(self: @EventsFilter) -> ContractEvents {
            let events = (*self.events.events).span();
            let mut filtered_events = array![];

            for i in 0
                ..events
                    .len() {
                        let (from, event) = events.at(i).clone();
                        let mut include = true;

                        if let Option::Some(addr) = self.contract_address {
                            if from != *addr {
                                include = false;
                            }
                        }

                        if include && self.key_filter.is_some() {
                            if !(event.keys.span() == (*self.key_filter).unwrap()) {
                                include = false;
                            }
                        }

                        if include && self.data_filter.is_some() {
                            if !event.data.includes((*self.data_filter).unwrap()) {
                                include = false;
                            }
                        }

                        if include {
                            filtered_events.append(event.clone());
                        }
                    };

            ContractEvents { events: filtered_events.span() }
        }
    }

    pub trait ContractEventsTrait {
        fn assert_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: @ContractEvents, event: @T
        );
        fn assert_not_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: @ContractEvents, event: @T
        );
    }

    impl ContractEventsTraitImpl of ContractEventsTrait {
        fn assert_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: @ContractEvents, event: @T
        ) {
            let mut expected_keys = array![];
            let mut expected_data = array![];
            event.append_keys_and_data(ref expected_keys, ref expected_data);

            let contract_events = (*self.events);
            let mut found = false;
            for i in 0
                ..contract_events
                    .len() {
                        let event = contract_events.at(i);
                        if event.keys == @expected_keys && event.data == @expected_data {
                            found = true;
                            break;
                        }
                    };

            assert(found, 'Expected event was not emitted');
        }

        fn assert_not_emitted<T, impl TEvent: starknet::Event<T>, impl TDrop: Drop<T>>(
            self: @ContractEvents, event: @T
        ) {
            let mut expected_keys = array![];
            let mut expected_data = array![];
            event.append_keys_and_data(ref expected_keys, ref expected_data);

            let contract_events = (*self.events);
            for i in 0
                ..contract_events
                    .len() {
                        let event = contract_events.at(i);
                        assert(
                            event.keys != @expected_keys || event.data != @expected_data,
                            'Unexpected event was emitted'
                        );
                    }
        }
    }

    /// Stores a value in the EVM storage of a given Starknet contract.
    pub fn store_evm(target: Address, evm_key: u256, evm_value: u256) {
        let storage_address = compute_storage_key(target.evm, evm_key);
        let serialized_value = [evm_value.low.into(), evm_value.high.into()].span();
        for offset in 0
            ..serialized_value
                .len() {
                    store_felt252(
                        target.starknet,
                        storage_address + offset.into(),
                        *serialized_value.at(offset)
                    );
                };
    }
}
