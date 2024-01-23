%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_read
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.dict_access import DictAccess

from kakarot.model import model
from kakarot.account import Account

func test__init__should_return_account_with_default_dict_as_storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    local evm_address: felt;
    local code_len: felt;
    let (code) = alloc();
    local nonce: felt;
    local balance_low: felt;
    %{
        ids.evm_address = program_input["evm_address"]
        ids.code_len = len(program_input["code"])
        segments.write_arg(ids.code, program_input["code"])
        ids.nonce = program_input["nonce"]
        ids.balance_low = program_input["balance_low"]
    %}

    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet=starknet_address, evm=evm_address);
    tempvar balance = new Uint256(balance_low, 0);

    // When
    let account = Account.init(address, code_len, code, nonce, balance);

    // Then
    assert account.address = address;
    assert account.code_len = code_len;
    assert account.nonce = nonce;
    assert account.balance.low = balance_low;
    assert account.balance.high = 0;
    assert account.selfdestruct = 0;
    let storage = account.storage;
    let (value) = dict_read{dict_ptr=storage}(0xdead);
    assert value = 0;
    return ();
}

func test__copy__should_return_new_account_with_same_attributes{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    local evm_address: felt;
    local code_len: felt;
    let (code) = alloc();
    local nonce: felt;
    local balance_low: felt;
    %{
        ids.evm_address = program_input["evm_address"]
        ids.code_len = len(program_input["code"])
        segments.write_arg(ids.code, program_input["code"])
        ids.nonce = program_input["nonce"]
        ids.balance_low = program_input["balance_low"]
    %}

    let starknet_address = Account.compute_starknet_address(evm_address);
    tempvar address = new model.Address(starknet=starknet_address, evm=evm_address);
    tempvar balance = new Uint256(balance_low, 0);
    let account = Account.init(address, code_len, code, nonce, balance);
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
    assert account.balance.low = balance_low;
    assert account.balance.high = 0;
    assert account.selfdestruct = account_copy.selfdestruct;

    // Same storage
    let storage_len = account.storage - account.storage_start;
    let storage_copy_len = account_copy.storage - account_copy.storage_start;
    assert storage_len = storage_copy_len;
    let (account_copy, value_copy) = Account.read_storage(account_copy, key);
    assert_uint256_eq([value], [value_copy]);

    // Updating copy doesn't update original
    tempvar new_value = new Uint256(5, 6);
    let account_copy = Account.write_storage(account_copy, key, new_value);
    let (account, value_original) = Account.read_storage(account, key);
    assert_uint256_eq([value], [value_original]);

    return ();
}

func test__write_storage__should_store_value_at_key{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let (key_ptr) = alloc();
    let (value_ptr) = alloc();

    %{
        segments.write_arg(ids.key_ptr, program_input["key"])
        segments.write_arg(ids.value_ptr, program_input["value"])
    %}

    let key = cast(key_ptr, Uint256*);
    let value = cast(value_ptr, Uint256*);

    let starknet_address = Account.compute_starknet_address(0);
    tempvar address = new model.Address(starknet_address, 0);
    let (local code: felt*) = alloc();
    tempvar balance = new Uint256(0, 0);
    let account = Account.init(address, 0, code, 0, balance);

    // When
    let account = Account.write_storage(account, key, value);

    // Then
    let storage_len = account.storage - account.storage_start;
    assert storage_len = DictAccess.SIZE;
    let (account, value_read) = Account.read_storage(account, key);
    assert_uint256_eq([value_read], [value]);

    return ();
}

func test__has_code_or_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    output_ptr: felt*
) {
    alloc_locals;
    // Given
    local code_len: felt;
    let (code) = alloc();
    local nonce: felt;
    %{
        ids.code_len = len(program_input["code"])
        segments.write_arg(ids.code, program_input["code"])
        ids.nonce = program_input["nonce"]
    %}

    let starknet_address = Account.compute_starknet_address(0);
    tempvar address = new model.Address(starknet_address, 0);
    tempvar balance = new Uint256(0, 0);
    let account = Account.init(address, code_len, code, nonce, balance);

    // When
    let result = Account.has_code_or_nonce(account);

    // Then
    assert [output_ptr] = result;
    return ();
}
