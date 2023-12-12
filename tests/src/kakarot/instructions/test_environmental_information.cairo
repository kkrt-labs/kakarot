// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.token.erc20.library import ERC20
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

from data_availability.starknet import Starknet
from kakarot.storages import account_proxy_class_hash, native_token_address
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IKakarot, IContractAccount, IAccount
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

@storage_var
func external_account_address() -> (model.Address,) {
}

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    native_token_address_: felt,
    contract_account_class_hash_: felt,
    account_proxy_class_hash_,
    bytecode_len: felt,
    bytecode: felt*,
) {
    alloc_locals;
    native_token_address.write(native_token_address_);
    account_proxy_class_hash.write(account_proxy_class_hash_);

    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    IContractAccount.write_bytecode(starknet_contract_address, bytecode_len, bytecode);
    let address = model.Address(starknet_contract_address, evm_contract_address);
    external_account_address.write(address);
    return ();
}

// @dev The contract account initialization includes a call to the caller contract
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    let (native_token_address_) = native_token_address.read();
    return (native_token_address_,);
}

// @dev The contract account initialization includes a call to an ERC20 contract to set an infitite transfer allowance to Kakarot.
@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

@view
func test__exec_address__should_push_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let (bytecode) = alloc();
    let address = 0xdead;
    let evm = TestHelpers.init_evm_at_address(0, bytecode, 0, address);

    // When
    with stack, memory, state {
        let result = EnvironmentalInformation.exec_address(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert index0.low = address;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_extcodesize__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    // When
    with stack, memory, state {
        Stack.push_uint128(0xdead);
        let evm = EnvironmentalInformation.exec_extcodesize(evm);
        let (extcodesize) = Stack.peek(0);
    }

    // Then
    assert extcodesize.low = 0;
    assert extcodesize.high = 0;

    return ();
}

@external
func test__exec_extcodesize__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let evm = TestHelpers.init_evm();
    let (address) = external_account_address.read();
    let address_uint256 = Helpers.to_uint256(address.evm);

    // When
    with stack, memory, state {
        Stack.push(address_uint256);
        let evm = EnvironmentalInformation.exec_extcodesize(evm);
        let (extcodesize) = Stack.peek(0);
    }

    // Then
    let (bytecode_len) = IAccount.bytecode_len(address.starknet);
    assert extcodesize.low = bytecode_len;
    assert extcodesize.high = 0;

    return ();
}

@external
func test__exec_extcodecopy__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (memory_len: felt, memory: felt*) {
    alloc_locals;

    // Given
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let size = 32;
    let offset = 0;
    let dest_offset = 0;
    tempvar item_3 = new Uint256(size, 0);  // size
    tempvar item_2 = new Uint256(offset, 0);  // offset
    tempvar item_1 = new Uint256(dest_offset, 0);  // dest_offset
    tempvar item_0 = new Uint256(0xDEAD, 0);  // address

    // When
    with stack, memory, state {
        Stack.push(item_3);  // size
        Stack.push(item_2);  // offset
        Stack.push(item_1);  // dest_offset
        Stack.push(item_0);  // address
        let evm = EnvironmentalInformation.exec_extcodecopy(evm);
        let (output_array) = alloc();
        Memory.load_n(size, output_array, dest_offset);
    }

    // Then
    assert stack.size = 0;
    return (memory_len=size, memory=output_array);
}

@external
func test__exec_extcodecopy__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(size: felt, offset: felt, dest_offset: felt) -> (memory_len: felt, memory: felt*) {
    alloc_locals;

    // Given
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    tempvar item_3 = new Uint256(size, 0);  // size
    tempvar item_2 = new Uint256(offset, 0);  // offset
    tempvar item_1 = new Uint256(dest_offset, 0);  // dest_offset
    let (address) = external_account_address.read();
    let item_0 = Helpers.to_uint256(address.evm);

    // When
    with stack, memory, state {
        Stack.push(item_3);  // size
        Stack.push(item_2);  // offset
        Stack.push(item_1);  // dest_offset
        Stack.push(item_0);  // address
        let evm = EnvironmentalInformation.exec_extcodecopy(evm);
        let (output_array) = alloc();
        Memory.load_n(size, output_array, dest_offset);
    }

    // Then
    assert stack.size = 0;
    return (memory_len=size, memory=output_array);
}

@external
func test__exec_gasprice{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let expected_gas_price_uint256 = Helpers.to_uint256(evm.message.gas_price);

    // When
    with stack, memory, state {
        let result = EnvironmentalInformation.exec_gasprice(evm);
        let (gasprice) = Stack.peek(0);
    }

    // Then
    assert_uint256_eq([gasprice], [expected_gas_price_uint256]);
    return ();
}

@external
func test__exec_extcodehash__should_handle_invalid_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let evm = TestHelpers.init_evm();
    tempvar address = new Uint256(0xDEAD, 0);

    // When
    with stack, memory, state {
        Stack.push(address);
        let result = EnvironmentalInformation.exec_extcodehash(evm);
        let (extcodehash) = Stack.peek(0);
    }

    // Then
    assert extcodehash.low = 0;
    assert extcodehash.high = 0;

    return ();
}

@external
func test__exec_extcodehash__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(expected_hash_low: felt, expected_hash_high: felt) {
    // Given
    alloc_locals;
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    // When
    with stack, memory, state {
        let (address) = external_account_address.read();
        let address_uint256 = Helpers.to_uint256(address.evm);
        Stack.push(address_uint256);
        let result = EnvironmentalInformation.exec_extcodehash(evm);
        let (extcodehash) = Stack.peek(0);
    }

    // Then
    assert extcodehash.low = expected_hash_low;
    assert extcodehash.high = expected_hash_high;

    return ();
}
