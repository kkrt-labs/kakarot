use snforge_std::{
    ContractClassTrait, ContractClass, declare, DeclareResultTrait, EventSpyTrait,
    start_cheat_block_timestamp_global, start_cheat_caller_address, mock_call, spy_events, store,
    load
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starknet::account::Call;
use starknet::class_hash::ClassHash;
use protocol_handler::{
    IProtocolHandlerDispatcher, IProtocolHandlerDispatcherTrait, ProtocolHandler,
    IProtocolHandlerSafeDispatcher, IProtocolHandlerSafeDispatcherTrait
};
use snforge_utils::snforge_utils::{
    EventsFilterBuilderTrait, ContractEventsTrait, assert_called_with
};

use openzeppelin_access::accesscontrol::AccessControlComponent;
use openzeppelin_access::accesscontrol::AccessControlComponent::{
    InternalImpl, RoleGranted, RoleRevoked
};
use openzeppelin_access::accesscontrol::interface::IAccessControlDispatcher;
use openzeppelin_access::accesscontrol::interface::IAccessControlDispatcherTrait;

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

fn gas_price_admin_mock() -> ContractAddress {
    contract_address_const::<'gas_price_admin_mock'>()
}

fn setup_contracts_for_testing() -> (IProtocolHandlerDispatcher, ContractClass) {
    // Mock Kakarot, security council, operator and guardians
    let kakarot_mock: ContractAddress = kakarot_mock();
    let security_council_mock: ContractAddress = security_council_mock();
    let operator_mock: ContractAddress = operator_mock();
    let gas_price_admin_mock: ContractAddress = gas_price_admin_mock();
    let guardians: Span<ContractAddress> = guardians_mock();

    // Construct the calldata for the ProtocolHandler contrustor
    let mut constructor_calldata: Array::<felt252> = array![
        kakarot_mock.into(),
        security_council_mock.into(),
        operator_mock.into(),
        gas_price_admin_mock.into()
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

#[test]
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
#[should_panic(expected: 'PROTOCOL_ALREADY_PAUSED')]
fn test_protocol_handler_soft_pause_should_fail_already_paused() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Simulate pausing by writing in the storage
    // Find the storage address for the ProtocolFrozenUntil
    let mut state = ProtocolHandler::contract_state_for_testing();
    let storage_address = state.protocol_frozen_until;
    let value = (get_block_timestamp() + 1);
    let mut serialized_value: Array::<felt252> = array![];
    Serde::serialize(@value, ref serialized_value);
    // Store the value in the storage of the protocol handler
    store(
        protocol_handler.contract_address, storage_address.__base_address__, serialized_value.span()
    );

    // Change caller to a guardian
    let guardians = guardians_mock();
    start_cheat_caller_address(protocol_handler.contract_address, *guardians[0]);

    // Call the protocol handler soft_pause, should fail as protocol is already paused
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

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_execute_call_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler execute_call, should fail as caller is not operator
    let call = Call { to: kakarot_mock(), selector: 0, calldata: [].span() };
    protocol_handler.execute_call(call);
}

#[test]
#[should_panic(expected: 'UNAUTHORIZED_SELECTOR')]
fn test_protocol_handler_execute_call_should_fail_unauthorized_selector() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to operator
    start_cheat_caller_address(protocol_handler.contract_address, operator_mock());

    // Construct the Call to a random address
    let random_called_address = contract_address_const::<'random_called_address'>();
    let call = Call { to: random_called_address, selector: 0, calldata: [].span() };

    // Call the protocol handler execute_call, should fail as the selector is not authorized
    protocol_handler.execute_call(call);
}

#[test]
#[should_panic(expected: 'ONLY_KAKAROT_CAN_BE_CALLED')]
fn test_protocol_handler_execute_call_should_fail_wrong_destination() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to operator
    start_cheat_caller_address(protocol_handler.contract_address, operator_mock());

    // Construct the Call to kakarot
    let random_called_address = contract_address_const::<'random_called_address'>();
    let call = Call {
        to: random_called_address, selector: selector!("set_native_token"), calldata: [].span()
    };

    // Call the protocol handler execute_call, should fail as the call is not to Kakarot
    protocol_handler.execute_call(call);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_set_base_fee_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler set_base_fee, should fail as caller is not operator
    protocol_handler.set_base_fee(0);
}

#[test]
fn test_protocol_handler_set_base_fee_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to gas price admin
    start_cheat_caller_address(protocol_handler.contract_address, gas_price_admin_mock());

    // Mock the call to Kakarot set_base_fee function
    mock_call::<()>(kakarot_mock(), selector!("set_base_fee"), (), 1);

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler set_base_fee, should pass as caller is gas price admin
    protocol_handler.set_base_fee(0);

    // Assert that unpause was called on Kakarot
    assert_called_with::<felt252>(kakarot_mock(), selector!("set_base_fee"), 0);

    // Check the BaseFeeChanged event is emitted
    let expected = ProtocolHandler::Event::BaseFeeChanged(
        ProtocolHandler::BaseFeeChanged { new_base_fee: 0 }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected);
}

#[test]
fn test_protocol_handler_execute_call_wrong_selector_should_fail() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    let unauthoried_selectors = [
        selector!("upgrade"),
        selector!("transfer_ownership"),
        selector!("pause"),
        selector!("unpause"),
    ];

    // Change the caller to operator
    start_cheat_caller_address(protocol_handler.contract_address, operator_mock());

    // Get SafeDispatcher of protocolHandler
    let safe_dispatcher = IProtocolHandlerSafeDispatcher {
        contract_address: protocol_handler.contract_address
    };

    for selector in unauthoried_selectors
        .span() {
            // Mock the call to the Kakarot entrypoint
            mock_call::<()>(kakarot_mock(), *selector, (), 1);

            // Construct the Call to protocol handler and call execute_call
            // Should pass as caller is operator and call is to Kakarot
            let call = Call { to: kakarot_mock(), selector: *selector, calldata: [].span() };

            // Call the protocol handler execute_call
            #[feature("safe_dispatcher")]
            match safe_dispatcher.execute_call(call) {
                Result::Ok(_) => panic!("Entrypoint did not panic"),
                Result::Err(panic_data) => {
                    assert(*panic_data.at(0) == 'UNAUTHORIZED_SELECTOR', *panic_data.at(0));
                }
            };
        }
}

#[test]
fn test_protocol_handler_execute_call_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    let authorized_selectors = [
        selector!("set_native_token"),
        selector!("set_coinbase"),
        selector!("set_prev_randao"),
        selector!("set_block_gas_limit"),
        selector!("set_account_contract_class_hash"),
        selector!("set_uninitialized_account_class_hash"),
        selector!("set_authorized_cairo_precompile_caller"),
        selector!("set_cairo1_helpers_class_hash"),
        selector!("upgrade_account"),
        selector!("set_authorized_pre_eip155_tx"),
        selector!("set_l1_messaging_contract_address"),
    ];

    // Change caller to operator
    start_cheat_caller_address(protocol_handler.contract_address, operator_mock());

    for selector in authorized_selectors
        .span() {
            // Mock the call to Kakarot entrypoint
            mock_call::<()>(kakarot_mock(), *selector, (), 1);

            // Construct the Call to protocol handler and call execute_call
            // Should pass as caller is operator and call is to Kakarot
            let call = Call { to: kakarot_mock(), selector: *selector, calldata: [].span() };

            // Spy on the events
            let mut spy = spy_events();

            // Call the protocol handler execute_call
            protocol_handler.execute_call(call);

            // Assert that selector was called on Kakarot
            assert_called_with::<()>(kakarot_mock(), *selector, ());

            // Check the ExecuteCall event is emitted
            let expected = ProtocolHandler::Event::Execution(
                ProtocolHandler::Execution { call: call }
            );
            let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
                .with_contract_address(protocol_handler.contract_address)
                .build();
            contract_events.assert_emitted(@expected);
        }
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_change_operator_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler change_operator, should fail as caller is not security council
    let new_operator = contract_address_const::<'new_operator'>();
    protocol_handler.change_operator(new_operator);
}

#[test]
fn test_protocol_handler_change_operator_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler change_operator
    let new_operator = contract_address_const::<'new_operator'>();
    protocol_handler.change_operator(new_operator);

    // Check the old operator is revoked and the new operator is granted
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: protocol_handler.contract_address
    };
    assert!(
        !access_control_dispatcher.has_role(ProtocolHandler::OPERATOR_ROLE, operator_mock()),
    );
    assert!(
        access_control_dispatcher.has_role(ProtocolHandler::OPERATOR_ROLE, new_operator),
    );

    // Check the Access control related events are emitted
    let expected_revoked = AccessControlComponent::Event::RoleRevoked(
        RoleRevoked {
            role: ProtocolHandler::OPERATOR_ROLE,
            account: operator_mock(),
            sender: security_council_mock()
        }
    );
    let expected_granted = AccessControlComponent::Event::RoleGranted(
        RoleGranted {
            role: ProtocolHandler::OPERATOR_ROLE,
            account: new_operator,
            sender: security_council_mock()
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected_revoked);
    contract_events.assert_emitted(@expected_granted);

    // Check the new operator is set in the contract state
    let loaded = load(protocol_handler.contract_address, selector!("operator"), 1);
    assert_eq!(*loaded[0], new_operator.into());
}


#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_change_security_council_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler change_security_council, should fail as caller is not security
    // council
    let new_security_council = contract_address_const::<'new_security_council'>();
    protocol_handler.change_security_council(new_security_council);
}

#[test]
fn test_protocol_handler_change_security_council_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler change_security_council
    let new_security_council = contract_address_const::<'new_security_council'>();
    protocol_handler.change_security_council(new_security_council);

    // Check the old security council is revoked and the new security council is granted
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: protocol_handler.contract_address
    };
    assert(
        !access_control_dispatcher
            .has_role(ProtocolHandler::SECURITY_COUNCIL_ROLE, security_council_mock()),
        'Old SC not revoked'
    );
    assert(
        access_control_dispatcher
            .has_role(ProtocolHandler::SECURITY_COUNCIL_ROLE, new_security_council),
        'New SC not granted'
    );

    // Check the Access control related events are emitted
    let expected_revoked = AccessControlComponent::Event::RoleRevoked(
        RoleRevoked {
            role: ProtocolHandler::SECURITY_COUNCIL_ROLE,
            account: security_council_mock(),
            sender: security_council_mock()
        }
    );
    let expected_granted = AccessControlComponent::Event::RoleGranted(
        RoleGranted {
            role: ProtocolHandler::SECURITY_COUNCIL_ROLE,
            account: new_security_council,
            sender: security_council_mock()
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected_revoked);
    contract_events.assert_emitted(@expected_granted);

    // Check the new security council is set in the contract state
    let loaded = load(protocol_handler.contract_address, selector!("security_council"), 1);
    assert_eq!(*loaded[0], new_security_council.into(), "New SC not set");
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_change_gas_price_admin_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler change_gas_price_admin, should fail as caller is not security
    // council
    let new_gas_price_admin = contract_address_const::<'new_gas_price_admin'>();
    protocol_handler.change_gas_price_admin(new_gas_price_admin);
}

#[test]
fn test_protocol_handler_change_gas_price_admin_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler change_gas_price_admin
    let new_gas_price_admin = contract_address_const::<'new_gas_price_admin'>();
    protocol_handler.change_gas_price_admin(new_gas_price_admin);

    // Check the old gas price admin is revoked and the new gas price admin is granted
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: protocol_handler.contract_address
    };
    assert(
        !access_control_dispatcher
            .has_role(ProtocolHandler::GAS_PRICE_ADMIN_ROLE, gas_price_admin_mock()),
        'Old GPA not revoked'
    );
    assert(
        access_control_dispatcher
            .has_role(ProtocolHandler::GAS_PRICE_ADMIN_ROLE, new_gas_price_admin),
        'New GPA not granted'
    );

    // Check the Access control related events are emitted
    let expected_revoked = AccessControlComponent::Event::RoleRevoked(
        RoleRevoked {
            role: ProtocolHandler::GAS_PRICE_ADMIN_ROLE,
            account: gas_price_admin_mock(),
            sender: security_council_mock()
        }
    );
    let expected_granted = AccessControlComponent::Event::RoleGranted(
        RoleGranted {
            role: ProtocolHandler::GAS_PRICE_ADMIN_ROLE,
            account: new_gas_price_admin,
            sender: security_council_mock()
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected_revoked);
    contract_events.assert_emitted(@expected_granted);

    // Check the new  gas price admin is set in the contract state
    let loaded = load(protocol_handler.contract_address, selector!("gas_price_admin"), 1);
    assert_eq!(*loaded[0], new_gas_price_admin.into(), "New GPA not set");
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_add_guardian_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler add_guardian, should fail as caller is not security council
    let new_guardian = contract_address_const::<'new_guardian'>();
    protocol_handler.add_guardian(new_guardian);
}

#[test]
fn test_protocol_handler_add_guardian_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler add_guardian
    let new_guardian = contract_address_const::<'new_guardian'>();
    protocol_handler.add_guardian(new_guardian);

    // Check the new guardian is granted
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: protocol_handler.contract_address
    };
    assert(
        access_control_dispatcher.has_role(ProtocolHandler::GUARDIAN_ROLE, new_guardian),
        'New guardian not granted'
    );

    // Check the Access control related events are emitted
    let expected_granted = AccessControlComponent::Event::RoleGranted(
        RoleGranted {
            role: ProtocolHandler::GUARDIAN_ROLE,
            account: new_guardian,
            sender: security_council_mock()
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected_granted);
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_protocol_handler_remove_guardian_should_fail_wrong_caller() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to random caller address
    let random_caller = contract_address_const::<'random_caller'>();
    start_cheat_caller_address(protocol_handler.contract_address, random_caller);

    // Call the protocol handler remove_guardian, should fail as caller is not security council
    let guardian = guardians_mock()[0];
    protocol_handler.remove_guardian(*guardian);
}

#[test]
fn test_protocol_handler_remove_guardian_should_pass() {
    let (protocol_handler, _) = setup_contracts_for_testing();

    // Change caller to security council
    start_cheat_caller_address(protocol_handler.contract_address, security_council_mock());

    // Spy on the events
    let mut spy = spy_events();

    // Call the protocol handler remove_guardian
    let guardian = guardians_mock()[0];
    protocol_handler.remove_guardian(*guardian);

    // Check the guardian is revoked
    let access_control_dispatcher = IAccessControlDispatcher {
        contract_address: protocol_handler.contract_address
    };
    assert(
        !access_control_dispatcher.has_role(ProtocolHandler::GUARDIAN_ROLE, *guardian),
        'Guardian not revoked'
    );

    // Check the Access control related events are emitted
    let expected_revoked = AccessControlComponent::Event::RoleRevoked(
        RoleRevoked {
            role: ProtocolHandler::GUARDIAN_ROLE,
            account: *guardian,
            sender: security_council_mock()
        }
    );
    let contract_events = EventsFilterBuilderTrait::from_events(@spy.get_events())
        .with_contract_address(protocol_handler.contract_address)
        .build();
    contract_events.assert_emitted(@expected_revoked);
}
