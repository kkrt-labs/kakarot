// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.starknet.common.syscalls import get_contract_address

// Local dependencies
from kakarot.model import model
from kakarot.state import State, Internals
from kakarot.account import Account
from kakarot.storages import native_token_address

// Add a balanceOf for the accounts
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (contract_address) = get_contract_address();
    native_token_address.write(contract_address);
    return ();
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    return (Uint256(0, 0),);
}

@external
func test__init__should_return_state_with_default_dicts{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let state = State.init();

    // Then
    assert state.accounts - state.accounts_start = 0;
    assert state.events_len = 0;
    assert state.transfers_len = 0;

    let accounts = state.accounts;
    let (value) = dict_read{dict_ptr=accounts}(0xdead);
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
    tempvar key_0 = new Uint256(1, 2);
    tempvar key_1 = new Uint256(3, 4);
    tempvar value = new Uint256(3, 4);
    with state {
        State.write_storage(address_0.evm, key_0, value);
        State.write_storage(address_1.evm, key_0, value);
        State.write_storage(address_1.evm, key_1, value);

        // 3. Put some events
        let (local topics: felt*) = alloc();
        let (local data: felt*) = alloc();
        let event = model.Event(topics_len=0, topics=topics, data_len=0, data=data);
        State.add_event(event);

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
            transfers_len=1,
            transfers=state.transfers,
        );

        // When
        let state_copy = State.copy();
    }

    // Then

    // Storage
    let value_copy = State.read_storage{state=state_copy}(address_0.evm, key_0);
    assert_uint256_eq([value], [value_copy]);
    let value_copy = State.read_storage{state=state_copy}(address_1.evm, key_0);
    assert_uint256_eq([value], [value_copy]);
    let value_copy = State.read_storage{state=state_copy}(address_1.evm, key_1);
    assert_uint256_eq([value], [value_copy]);

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

@external
func test__is_account_alive__existing_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(nonce, code_len, code: felt*, balance_low) -> (is_alive: felt) {
    alloc_locals;
    let evm_address = 'alive';
    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet_address, evm_address);
    tempvar balance = new Uint256(balance_low, 0);
    let account = Account.init(address, code_len, code, nonce, balance);
    let state = State.init();

    with state {
        State.update_account(account);
        let is_alive = State.is_account_alive(evm_address);
    }

    return (is_alive=is_alive);
}

@external
func test__is_account_alive__not_in_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (is_alive: felt) {
    let state = State.init();
    with state {
        let is_alive = State.is_account_alive(0xdead);
    }

    return (is_alive=is_alive);
}

@external
func test___copy_accounts__should_handle_null_pointers{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let (accounts) = default_dict_new(0);
    tempvar accounts_start = accounts;
    tempvar address = new model.Address(1, 2);
    tempvar balance = new Uint256(1, 0);
    let (code) = alloc();
    let account = Account.init(address, 0, code, 1, balance);
    dict_write{dict_ptr=accounts}(address.evm, cast(account, felt));
    let empty_address = 'empty address';
    dict_read{dict_ptr=accounts}(empty_address);
    let (local accounts_copy: DictAccess*) = default_dict_new(0);
    tempvar accounts_copy_start = accounts_copy;
    Internals._copy_accounts{accounts=accounts_copy}(accounts_start, accounts);

    return ();
}
