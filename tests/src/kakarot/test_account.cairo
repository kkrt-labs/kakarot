// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.dict_access import DictAccess

// Local dependencies
from kakarot.model import model
from kakarot.account import Account

@external
func test__init__should_return_account_with_default_dict_as_storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt, code_len: felt, code: felt*, nonce: felt) {
    // When
    let account = Account.init(address, code_len, code, nonce);

    // Then
    assert account.address = address;
    assert account.code_len = code_len;
    assert account.nonce = nonce;
    assert account.selfdestruct = 0;
    let storage = account.storage;
    let (value) = dict_read{dict_ptr=storage}(0xdead);
    assert value = 0;
    return ();
}

@external
func test__copy__should_return_new_account_with_same_attributes{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt, code_len: felt, code: felt*, nonce: felt) {
    alloc_locals;
    // Given
    let account = Account.init(evm_address, code_len, code, nonce);
    tempvar key = new Uint256(1, 2);
    tempvar value = new Uint256(3, 4);
    let account = Account.write_storage(account, key, value);

    // When
    let account_copy = Account.copy(account);

    // Then

    // Same immutable attributes
    assert account.address = account_copy.address;
    assert account.code_len = account_copy.code_len;
    assert account.nonce = account_copy.nonce;
    assert account.selfdestruct = account_copy.selfdestruct;

    // Same storage
    let storage_len = account.storage - account.storage_start;
    let storage_copy_len = account_copy.storage - account_copy.storage_start;
    assert storage_len = storage_copy_len;
    tempvar address = new model.Address(0, evm_address);
    let (account_copy, value_copy) = Account.read_storage(account_copy, address, key);
    assert_uint256_eq([value], value_copy);

    // Updating copy doesn't update original
    tempvar new_value = new Uint256(5, 6);
    let account_copy = Account.write_storage(account_copy, key, new_value);
    let (account, value_original) = Account.read_storage(account, address, key);
    assert_uint256_eq([value], value_original);

    return ();
}

@external
func test__finalize__should_return_summary{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(evm_address: felt, code_len: felt, code: felt*, nonce: felt) {
    // Given
    alloc_locals;
    let account = Account.init(evm_address, code_len, code, nonce);
    tempvar key = new Uint256(1, 2);
    tempvar value = new Uint256(3, 4);
    tempvar address = new model.Address(0, evm_address);
    let account = Account.write_storage(account, key, value);
    let (account, value_read) = Account.read_storage(account, address, key);
    let (account, value_read) = Account.read_storage(account, address, key);
    let (account, value_read) = Account.read_storage(account, address, key);

    // When
    let summary = Account.finalize(account);

    // Then
    let account_storage_len = account.storage - account.storage_start;
    assert account_storage_len = 4 * DictAccess.SIZE;
    let summary_storage_len = summary.storage - summary.storage_start;
    assert summary_storage_len = 1 * DictAccess.SIZE;
    let (account, value_summary) = Account.read_storage(
        cast(summary, model.Account*), address, key
    );
    assert_uint256_eq(value_read, value_summary);

    return ();
}

@external
func test__finalize__should_return_summary_with_no_default_dict{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(evm_address: felt, code_len: felt, code: felt*, nonce: felt) {
    // Given
    alloc_locals;
    tempvar key = new Uint256(1, 2);
    tempvar address = new model.Address(0, evm_address);
    let account = Account.init(evm_address, code_len, code, nonce);

    // When
    let summary = Account.finalize(account);

    // Then
    with_attr error_message("KeyError") {
        Account.read_storage(cast(summary, model.Account*), address, key);
    }

    return ();
}
