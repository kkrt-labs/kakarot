// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc

// Local dependencies
from kakarot.model import model
from kakarot.state import State
from kakarot.account import Account

@external
func test__init__should_return_state_with_default_dicts{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let state = State.init();

    // Then
    assert state.accounts - state.accounts_start = 0;
    assert state.events_len = 0;
    assert state.balances - state.balances_start = 0;
    assert state.transfers_len = 0;

    let accounts = state.accounts;
    let (value) = dict_read{dict_ptr=accounts}(0xdead);
    assert value = 0;

    let balances = state.balances;
    let (value) = dict_read{dict_ptr=balances}(0xdead);
    assert value = 0;

    return ();
}

@external
func test__copy__should_return_new_state_with_same_attributes{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given

    // 1. Create empty State
    let state = State.init();

    // 2. Put two accounts with some storage
    tempvar address_0 = new model.Address(1, 2);
    tempvar address_1 = new model.Address(3, 4);
    tempvar key_0 = Uint256(1, 2);
    tempvar key_1 = Uint256(3, 4);
    tempvar value = new Uint256(3, 4);
    let state = State.write_storage(state, address_0, key_0, value);
    let state = State.write_storage(state, address_1, key_0, value);
    let state = State.write_storage(state, address_1, key_1, value);

    // 3. Put some events
    let (local topics: felt*) = alloc();
    let (local data: felt*) = alloc();
    let event = model.Event(topics_len=0, topics=topics, data_len=0, data=data);
    let state = State.add_event(state, event);

    // 4. Add transfers
    // State.add_transfer requires a native token contract deployed so we just push.
    let amount = Uint256(0xa, 0xb);
    tempvar transfer = model.Transfer(address_0, address_1, amount);
    assert state.transfers[0] = transfer;
    tempvar state = new model.State(
        accounts_start=state.accounts_start,
        accounts=state.accounts,
        events_len=state.events_len,
        events=state.events,
        balances_start=state.balances_start,
        balances=state.balances,
        transfers_len=1,
        transfers=state.transfers,
    );

    // When
    let state_copy = State.copy(state);

    // Then

    // Storage
    let (state_copy, value_copy) = State.read_storage(state_copy, address_0, key_0);
    assert_uint256_eq([value], value_copy);
    let (state_copy, value_copy) = State.read_storage(state_copy, address_1, key_0);
    assert_uint256_eq([value], value_copy);
    let (state_copy, value_copy) = State.read_storage(state_copy, address_1, key_1);
    assert_uint256_eq([value], value_copy);

    // Events
    assert state_copy.events_len = state.events_len;

    // Transfers
    assert state_copy.transfers_len = state.transfers_len;
    let transfer_copy = state_copy.transfers;
    assert transfer.sender.starknet = transfer_copy.sender.starknet;
    assert transfer.sender.evm = transfer_copy.sender.evm;
    assert transfer.recipient.starknet = transfer_copy.recipient.starknet;
    assert transfer.recipient.evm = transfer_copy.recipient.evm;
    assert_uint256_eq(transfer.amount, transfer_copy.amount);

    return ();
}
