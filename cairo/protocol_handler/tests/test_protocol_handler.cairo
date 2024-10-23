use snforge_std::{
    ContractClassTrait, ContractClass, declare, DeclareResultTrait, EventSpyTrait,
    start_cheat_block_timestamp_global, start_cheat_caller_address, mock_call, spy_events, store
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::account::Call;
use starknet::class_hash::ClassHash;
use protocol_handler::{
    IProtocolHandlerDispatcher, IProtocolHandlerDispatcherTrait, ProtocolHandler
};

use snforge_utils::snforge_utils::{
    EventsFilterBuilderTrait, ContractEventsTrait, assert_called_with
};

fn kakarot_mock() -> ContractAddress {
    contract_address_const::<'security_council_mock'>()
}

fn security_council_mock() -> ContractAddress {
    contract_address_const::<'security_council_mock'>()
}

fn operator_mock() -> ContractAddress {
    contract_address_const::<'operator_mock'>()
}

fn guardians_mock() -> Span<ContractAddress> {
    array![
        contract_address_const::<'guardian_mock_1'>(), contract_address_const::<'guardian_mock_2'>()
    ]
        .span()
}

fn setup_contracts_for_testing() -> (IProtocolHandlerDispatcher, ContractClass) {
    // Mock Kakarot, security council, operator and guardians
    let kakarot_mock: ContractAddress = kakarot_mock();
    let security_council_mock: ContractAddress = security_council_mock();
    let operator_mock: ContractAddress = operator_mock();
    let guardians: Span<ContractAddress> = guardians_mock();

    // Construct the calldata for the ProtocolHandler contrustor
    let mut constructor_calldata: Array::<felt252> = array![
        kakarot_mock.into(), security_council_mock.into(), operator_mock.into()
    ];
    Serde::serialize(@guardians, ref constructor_calldata);
    let contract = declare("ProtocolHandler").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    // Get The dispatcher for the ProtocolHandler
    let protocol_handler = IProtocolHandlerDispatcher { contract_address };

    return (protocol_handler, *contract);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_emergency_execution_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call emergency_execution, should fail as caller is not security council
    let call = Call { to: kakarot_mock(), selector: 0, calldata: [].span() };
    protocol_handler.emergency_execution(call);
}

#[test]
#[should_panic(expected: 'ONLY_KAKAROT_CAN_BE_CALLED')]
fn test_protocol_emergency_execution_fail_wrong_destination() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Construct the Call to a random address
    let random_called_address = contract_address_const::<'random_called_address'>();
    let call = Call { to: random_called_address, selector: 0, calldata: [].span() };

    // Call emergency_execution, should fail as the call is not to Kakarot
    protocol_handler.emergency_execution(call);
}

#[test]
fn test_protocol_emergency_execution_should_pass() {
    let (protocol_handler, contract) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Mock the call to Kakarot upgrade function
    mock_call::<()>(kakarot_mock(), selector!("upgrade"), (), 1);

    // Construct the Call to protocol handler and call emergency_execution
    // Should pass as caller is security council and call is to Kakarot
    let calldata = contract.class_hash;
    let mut serialized_calldata: Array::<felt252> = array![];
    Serde::serialize(@calldata, ref serialized_calldata);
    let call = Call {
        to: kakarot_mock(), selector: selector!("upgrade"), calldata: serialized_calldata.span()
    };

    // Spy on the events
    let mut spy = spy_events();
    protocol_handler.emergency_execution(call);

    // Assert that upgrade was called on Kakarot
    assert_called_with::<ClassHash>(kakarot_mock(), selector!("upgrade"), contract.class_hash);

    // Check the EmergencyExecution event is emitted
    let expected = ProtocolHandler::Event::EmergencyExecution(
        ProtocolHandler::EmergencyExecution { call: call }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_upgrade_fail_wrong_caller() {
    let (protocol_handler, contract) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler upgrade, should fail as caller is not operator
    protocol_handler.upgrade(contract.class_hash);
}

fn test_protocol_upgrade_should_pass() {
    let (protocol_handler, contract) = setup_contracts_for_testing();

    // Mock the call to Kakarot upgrade function
    mock_call::<()>(kakarot_mock(), selector!("upgrade"), (), 1);

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, operator_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler upgrade, should pass as caller is operator
    protocol_handler.upgrade(contract.class_hash);

    // Assert that upgrade was called on Kakarot
    assert_called_with::<ClassHash>(kakarot_mock(), selector!("upgrade"), contract.class_hash);

    // Check the TransferOwnership event is emitted
    let expected = ProtocolHandler::Event::Upgrade(
        ProtocolHandler::Upgrade { new_class_hash: contract.class_hash }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_transfer_ownership_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to not security council
    let not_security_council = contract_address_const::<'not_security_council'>();
    start_cheat_caller_address(protocol_handler.contract_address, not_security_council);

    // Call the protocol handler transfer_ownership, should fail as caller is not security council
    let new_owner = contract_address_const::<'new_owner'>();
    protocol_handler.transfer_ownership(new_owner);
}

#[test]
fn test_protocol_handler_transfer_ownership_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Mock the call to Kakarot transfer_ownership
    mock_call::<()>(kakarot_mock(), selector!("transfer_ownership"), (), 1);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler transfer_ownership
    let new_owner = contract_address_const::<'new_owner'>();
    protocol_handler.transfer_ownership(new_owner);

    // Assert that transfer_ownership was called on Kakarot
    assert_called_with::<
        ContractAddress
    >(kakarot_mock(), selector!("transfer_ownership"), new_owner);

    // Check the TransferOwnership event is emitted
    let expected = ProtocolHandler::Event::TransferOwnership(
        ProtocolHandler::TransferOwnership { new_owner: new_owner }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}


#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_soft_pause_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler soft_pause, should fail as caller is not guardian
    protocol_handler.soft_pause();
}

#[test]
fn test_protocol_handler_soft_pause_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Mock the call to kakarot pause function
    mock_call::<()>(kakarot_mock(), selector!("pause"), (), 1);

    // Change caller to a guardian
    let guardians = guardians_mock();
    start_cheat_caller_address(protocol_handler.contract_address, *guardians[0]);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler soft_pause, should pass as caller is guardian
    protocol_handler.soft_pause();

    // Assert that pause was called on Kakarot
    assert_called_with::<()>(kakarot_mock(), selector!("pause"), ());

    // Check the SoftPause event is emitted
    let expected = ProtocolHandler::Event::SoftPause(
        ProtocolHandler::SoftPause {
            protocol_frozen_until: ProtocolHandler::SOFT_PAUSE_DELAY // Blocktimestamp is 0 in tests
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_hard_pause_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to not security council
    let not_security_council = contract_address_const::<'not_security_council'>();
    start_cheat_caller_address(protocol_handler.contract_address, not_security_council);

    // Call the protocol handler hard_pause, should fail as caller is not security council
    protocol_handler.hard_pause();
}

#[test]
fn test_protocol_handler_hard_pause_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Mock the call to kakarot pause function
    mock_call::<()>(kakarot_mock(), selector!("pause"), (), 1);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler hard_pause, should pass as caller is security council
    protocol_handler.hard_pause();

    // Assert that pause was called on Kakarot
    assert_called_with::<()>(kakarot_mock(), selector!("pause"), ());

    // Check the HardPause event is emitted
    let expected = ProtocolHandler::Event::HardPause(
        ProtocolHandler::HardPause {
            protocol_frozen_until: ProtocolHandler::HARD_PAUSE_DELAY // Blocktimestamp is 0 in tests
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_unpause_should_fail_wrong_caller_when_too_soon() {
    // Block timestamp is 0 in tests, changing it to 10
    start_cheat_block_timestamp_global(10);
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Simulate pausing by writing in the storage
    // Find the storage address for the ProtocolFrozenUntil
    let mut state = ProtocolHandler::contract_state_for_testing();
    let storage_address = state.protocol_frozen_until;
    let value = (get_block_timestamp() * 10);
    let mut serialized_value: Array::<felt252> = array![];
    Serde::serialize(@value, ref serialized_value);
    // Store the value in the storage of the protocol handler
    store(
        protocol_handler.contract_address, storage_address.__base_address__, serialized_value.span()
    );

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler unpause, should fail as caller is not security council
    protocol_handler.unpause();
}

#[test]
fn test_protocol_handler_unpause_should_pass_security_council() {
    // Block timestamp is 0 in tests changing it to 10
    start_cheat_block_timestamp_global(10);
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Simulate pausing by writing in the storage
    // Find the storage address for the ProtocolFrozenUntil
    let mut state = ProtocolHandler::contract_state_for_testing();
    let storage_address = state.protocol_frozen_until;
    let value = (get_block_timestamp() * 10);
    let mut serialized_value: Array::<felt252> = array![];
    Serde::serialize(@value, ref serialized_value);
    // Store the value in the storage of the protocol handler
    store(
        protocol_handler.contract_address, storage_address.__base_address__, serialized_value.span()
    );

    // Change the caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Mock call to kakarot unpause function
    mock_call::<()>(kakarot_mock(), selector!("unpause"), (), 1);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler unpause, should pass as caller is security council
    protocol_handler.unpause();

    // Assert that unpause was called on Kakarot
    assert_called_with::<()>(kakarot_mock(), selector!("unpause"), ());

    // Check the Unpause event is emitted
    let expected = ProtocolHandler::Event::Unpause(ProtocolHandler::Unpause {});
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
fn test_protocol_handler_unpause_should_pass_after_delay() {
    // Block timestamp is 0 in tests
    start_cheat_block_timestamp_global(10);
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Simulate pausing by writing in the storage
    // Find the storage address for the ProtocolFrozenUntil
    let mut state = ProtocolHandler::contract_state_for_testing();
    let storage_address = state.protocol_frozen_until;
    let value = get_block_timestamp() - 1;
    let mut serialized_value: Array::<felt252> = array![];
    Serde::serialize(@value, ref serialized_value);
    // Store the value in the storage of the protocol handler
    store(
        protocol_handler.contract_address, storage_address.__base_address__, serialized_value.span()
    );

    // Mock call to kakarot unpause function
    mock_call::<()>(kakarot_mock(), selector!("unpause"), (), 1);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler unpause, should pass as caller is security council
    protocol_handler.unpause();

    // Assert that unpause was called on Kakarot
    assert_called_with::<()>(kakarot_mock(), selector!("unpause"), ());

    // Check the Unpause event is emitted
    let expected = ProtocolHandler::Event::Unpause(ProtocolHandler::Unpause {});
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}
