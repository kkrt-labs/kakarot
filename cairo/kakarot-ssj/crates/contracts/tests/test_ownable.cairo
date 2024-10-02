use contracts::components::ownable::{ownable_component};
use contracts::test_utils::constants::{ZERO, OWNER, OTHER};
use core::num::traits::Zero;
use core::starknet::ContractAddress;


use ownable_component::{InternalImpl, OwnableImpl};
use snforge_std::{start_cheat_caller_address, spy_events, test_address, EventSpyTrait};
use snforge_utils::snforge_utils::{EventsFilterBuilderTrait, ContractEventsTrait};


#[starknet::contract]
pub mod MockContract {
    use contracts::components::ownable::{ownable_component};

    component!(path: ownable_component, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = ownable_component::Ownable<ContractState>;

    impl OwnableInternalImpl = ownable_component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: ownable_component::Storage
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        OwnableEvent: ownable_component::Event
    }
}
type TestingState = ownable_component::ComponentState<MockContract::ContractState>;

impl TestingStateDefault of Default<TestingState> {
    fn default() -> TestingState {
        ownable_component::component_state_for_testing()
    }
}

#[generate_trait]
impl TestingStateImpl of TestingStateTrait {
    fn new_with(owner: ContractAddress) -> TestingState {
        let mut ownable: TestingState = Default::default();
        ownable.initializer(owner);
        ownable
    }
}

#[test]
fn test_ownable_initializer() {
    let mut ownable: TestingState = Default::default();
    let test_address: ContractAddress = test_address();
    assert(ownable.owner().is_zero(), 'owner should be zero');

    let mut spy = spy_events();
    ownable.initializer(OWNER());
    let expected = MockContract::Event::OwnableEvent(
        ownable_component::Event::OwnershipTransferred(
            ownable_component::OwnershipTransferred { previous_owner: ZERO(), new_owner: OWNER() }
        )
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(test_address)
        .build();
    contract_events.assert_emitted(@expected);
    assert(ownable.owner() == OWNER(), 'Owner should be set');
}

#[test]
fn test_assert_only_owner() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OWNER());

    ownable.assert_only_owner();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_assert_only_owner_not_owner() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OTHER());

    ownable.assert_only_owner();
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_assert_only_owner_zero() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, ZERO());
    ownable.assert_only_owner();
}

#[test]
fn test__transfer_ownership() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();

    let mut spy = spy_events();
    let expected = MockContract::Event::OwnableEvent(
        ownable_component::Event::OwnershipTransferred(
            ownable_component::OwnershipTransferred { previous_owner: OWNER(), new_owner: OTHER() }
        )
    );
    ownable._transfer_ownership(OTHER());

    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(test_address)
        .build();
    contract_events.assert_emitted(@expected);
    assert(ownable.owner() == OTHER(), 'Owner should be OTHER');
}


#[test]
fn test_transfer_ownership() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OWNER());

    let mut spy = spy_events();
    ownable.transfer_ownership(OTHER());
    let expected = MockContract::Event::OwnableEvent(
        ownable_component::Event::OwnershipTransferred(
            ownable_component::OwnershipTransferred { previous_owner: OWNER(), new_owner: OTHER() }
        )
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(test_address)
        .build();
    contract_events.assert_emitted(@expected);

    assert(ownable.owner() == OTHER(), 'Should transfer ownership');
}

#[test]
#[should_panic(expected: ('New owner is the zero address',))]
fn test_transfer_ownership_to_zero() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OWNER());

    ownable.transfer_ownership(ZERO());
}


#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_transfer_ownership_from_zero() {
    let mut ownable: TestingState = Default::default();

    ownable.transfer_ownership(OTHER());
}


#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_transfer_ownership_from_nonowner() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OTHER());

    ownable.transfer_ownership(OTHER());
}


#[test]
fn test_renounce_ownership() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();

    start_cheat_caller_address(test_address, OWNER());
    let mut spy = spy_events();
    ownable.renounce_ownership();
    let expected = MockContract::Event::OwnableEvent(
        ownable_component::Event::OwnershipTransferred(
            ownable_component::OwnershipTransferred { previous_owner: OWNER(), new_owner: ZERO() }
        )
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(test_address)
        .build();
    contract_events.assert_emitted(@expected);

    assert(ownable.owner().is_zero(), 'ownership not renounced');
}

#[test]
#[should_panic(expected: ('Caller is the zero address',))]
fn test_renounce_ownership_from_zero_address() {
    let mut ownable: TestingState = Default::default();
    ownable.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_renounce_ownership_from_nonowner() {
    let mut ownable: TestingState = TestingStateTrait::new_with(OWNER());
    let test_address: ContractAddress = test_address();
    start_cheat_caller_address(test_address, OTHER());

    ownable.renounce_ownership();
}
