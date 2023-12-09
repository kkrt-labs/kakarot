// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import split_felt, assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.cairo.common.memset import memset

// Local dependencies
from data_availability.starknet import Starknet
from kakarot.constants import Constants
from kakarot.storages import (
    native_token_address,
    contract_account_class_hash,
    account_proxy_class_hash,
)
from kakarot.evm import EVM
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from kakarot.account import Account
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.state import State
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers
from utils.uint256 import uint256_to_uint160

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(native_token_address_: felt, contract_account_class_hash_: felt, account_proxy_class_hash_) {
    native_token_address.write(native_token_address_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    contract_account_class_hash.write(contract_account_class_hash_);
    return ();
}

// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          MOCK FUNCTIONS                                                      //
// The Kakarot, EOA, Contract Account and ETH contracts often times require communication between each other.   //
// Instead of deploying each contract for every test-case we mock the required functions in this contract.      //
// ///////////////////////////////////////////////////////////////////////////////////////////////////////////////

//
// Kakarot
//

// @dev The contract account initialization includes a call to the Kakarot contract
// in order to get the native token address. As the Kakarot contract is not deployed within this test, we make a call to this contract instead.
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    let (native_token) = native_token_address.read();
    return (native_token,);
}

// @dev mock function that returns the computed starknet address from an evm address
@external
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    let (contract_address_) = Account.compute_starknet_address(evm_address);
    return (contract_address=contract_address_);
}

// ///////////////////
//    Test Cases    //
// ///////////////////

@external
func test__exec_return_should_return_context_with_updated_return_data{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(return_data: felt) {
    // Given
    alloc_locals;
    let bytecode: felt* = alloc();
    let stack: model.Stack* = Stack.init();

    // When
    let stack: model.Stack* = Stack.push_uint128(stack, return_data);
    let stack: model.Stack* = Stack.push_uint128(stack, 0);
    let evm: model.EVM* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let evm: model.EVM* = MemoryOperations.exec_mstore(evm);

    // Then
    let stack: model.Stack* = Stack.push_uint128(evm.stack, 32);
    let stack: model.Stack* = Stack.push_uint128(stack, 0);
    let evm: model.EVM* = EVM.update_stack(evm, stack);
    let evm: model.EVM* = SystemOperations.exec_return(evm);

    // Then
    let returned_data = Helpers.load_word(32, evm.return_data);
    assert return_data = returned_data;

    return ();
}

@external
func test__exec_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(reason_low: felt, reason_high: felt, size: felt) -> (
    revert_reason_len: felt, revert_reason: felt*
) {
    // Given
    alloc_locals;
    tempvar reason_uint256 = new Uint256(low=reason_low, high=reason_high);
    tempvar offset = new Uint256(32, 0);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, reason_uint256);  // value
    let stack: model.Stack* = Stack.push(stack, offset);  // offset
    let evm: model.EVM* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let evm: model.EVM* = MemoryOperations.exec_mstore(evm);

    let stack: model.Stack* = Stack.push_uint128(evm.stack, size);  // size
    let stack: model.Stack* = Stack.push_uint128(stack, 0);  // offset is 0 to have the reason at 0x20

    let evm: model.EVM* = EVM.update_stack(evm, stack);

    // When
    let evm = SystemOperations.exec_revert(evm);

    // Then
    assert evm.reverter = 1;
    assert evm.return_data_len = size;
    return (evm.return_data_len, evm.return_data);
}

@external
func test__exec_call__should_return_a_new_context_based_on_calling_evm_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack = Stack.init();
    let memory = Memory.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    let evm = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, 0, bytecode, stack
    );
    let evm = MemoryOperations.exec_mstore(evm);

    // When
    let child_evm = SystemOperations.exec_call(evm);

    // Then

    // assert than sub_context is well initialized
    assert child_evm.message.bytecode_len = 0;
    assert child_evm.message.calldata_len = 4;
    assert [child_evm.message.calldata] = 0x44;
    assert [child_evm.message.calldata + 1] = 0x55;
    assert [child_evm.message.calldata + 2] = 0x66;
    assert [child_evm.message.calldata + 3] = 0x77;
    assert child_evm.message.value = value.low;
    assert child_evm.program_counter = 0;
    assert child_evm.stopped = 0;
    assert child_evm.return_data_len = 0;
    assert child_evm.message.gas_price = 0;
    assert child_evm.message.address.starknet = callee_starknet_contract_address;
    assert child_evm.message.address.evm = callee_evm_contract_address;
    TestHelpers.assert_execution_context_equal(child_evm.message.parent, evm);

    // Fake a RETURN in child_evm then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    let (local return_data: felt*) = alloc();
    assert [return_data] = 0x11;
    let child_evm = EVM.stop(child_evm, 1, return_data, FALSE);
    let summary = EVM.finalize(child_evm);
    let evm = CallHelper.finalize_parent(summary);

    // Then
    let (stack, success) = Stack.peek(evm.stack, 0);
    assert success.low = 1;
    let (local loaded_return_data: felt*) = alloc();
    Memory.load_n(ret_size.low, loaded_return_data, ret_offset.low);
    assert [loaded_return_data] = 0x11;

    return ();
}

@external
func test__exec_call__should_transfer_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    let evm = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, 0, bytecode, stack
    );
    let evm = MemoryOperations.exec_mstore(evm);

    // Get the balance of caller pre-call
    tempvar caller_address = new model.Address(
        caller_starknet_contract_address, caller_evm_contract_address
    );
    let (state, caller_account_prev) = State.get_account(evm.state, caller_address);
    let evm = EVM.update_state(evm, state);

    // When
    let child_evm = SystemOperations.exec_call(evm);

    // Then
    // get balances of caller and callee post-call
    let state = child_evm.state;
    tempvar callee_address = new model.Address(
        callee_starknet_contract_address, callee_evm_contract_address
    );
    let (state, callee_account) = State.get_account(state, callee_address);
    let (state, caller_account_new) = State.get_account(state, caller_address);
    let (caller_diff_balance) = uint256_sub(
        [caller_account_prev.balance], [caller_account_new.balance]
    );
    assert [callee_account.balance] = Uint256(2, 0);
    assert caller_diff_balance = Uint256(2, 0);
    return ();
}

@external
func test__exec_callcode__should_return_a_new_context_based_on_calling_evm_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (_) = Starknet.deploy(contract_account_class_hash_, callee_evm_contract_address);

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let evm = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, bytecode_len, bytecode, stack
    );
    let evm = MemoryOperations.exec_mstore(evm);

    // When
    let child_evm = SystemOperations.exec_callcode(evm);

    // Then
    assert child_evm.message.bytecode_len = 0;
    assert child_evm.message.calldata_len = 4;
    assert [child_evm.message.calldata] = 0x44;
    assert [child_evm.message.calldata + 1] = 0x55;
    assert [child_evm.message.calldata + 2] = 0x66;
    assert [child_evm.message.calldata + 3] = 0x77;
    assert child_evm.message.value = value.low;
    assert child_evm.program_counter = 0;
    assert child_evm.stopped = 0;
    assert child_evm.message.gas_price = 0;
    assert child_evm.message.address.starknet = caller_starknet_contract_address;
    assert child_evm.message.address.evm = caller_evm_contract_address;
    TestHelpers.assert_execution_context_equal(child_evm.message.parent, evm);

    // Fake a RETURN in child_evm then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the child_evm does set proper values for return_data_len and return_data
    let child_evm = EVM.stop(child_evm, 0, child_evm.return_data, FALSE);
    let summary = EVM.finalize(child_evm);
    let evm = CallHelper.finalize_parent(summary);

    // Then
    let (stack, success) = Stack.peek(evm.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__exec_callcode__should_transfer_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy two empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (caller_evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (caller_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, caller_evm_contract_address
    );
    tempvar caller_address = new model.Address(
        caller_starknet_contract_address, caller_evm_contract_address
    );
    let (callee_evm_contract_address) = CreateHelper.get_create_address(1, 0);
    let (callee_starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, callee_evm_contract_address
    );
    tempvar callee_address = new model.Address(
        callee_starknet_contract_address, callee_evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(callee_evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar value = new Uint256(2, 0);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, value);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let evm = TestHelpers.init_context_at_address_with_stack(
        caller_starknet_contract_address, caller_evm_contract_address, bytecode_len, bytecode, stack
    );
    let evm = MemoryOperations.exec_mstore(evm);

    // Get the balance of caller pre-call
    let (state, caller_pre_account) = State.get_account(evm.state, caller_address);
    let evm = EVM.update_state(evm, state);

    // When
    let child_evm = SystemOperations.exec_callcode(evm);

    // Then
    // get balances of caller and callee post-call
    let state = child_evm.state;
    let (state, caller_post_account) = State.get_account(state, caller_address);

    assert caller_post_account.balance = caller_pre_account.balance;
    return ();
}

@external
func test__exec_staticcall__should_return_a_new_context_based_on_calling_evm_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let evm = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let evm = MemoryOperations.exec_mstore(evm);

    // When
    let child_evm = SystemOperations.exec_staticcall(evm);

    // Then
    assert child_evm.message.bytecode_len = 0;
    assert child_evm.message.calldata_len = 4;
    assert [child_evm.message.calldata] = 0x44;
    assert [child_evm.message.calldata + 1] = 0x55;
    assert [child_evm.message.calldata + 2] = 0x66;
    assert [child_evm.message.calldata + 3] = 0x77;
    assert child_evm.message.value = 0;
    assert child_evm.program_counter = 0;
    assert child_evm.stopped = 0;
    assert child_evm.message.gas_price = 0;
    assert child_evm.message.address.starknet = starknet_contract_address;
    assert child_evm.message.address.evm = evm_contract_address;
    TestHelpers.assert_execution_context_equal(child_evm.message.parent, evm);

    // Fake a RETURN in child_evm then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the child_evm does set proper values for return_data_len and return_data
    let child_evm = EVM.stop(child_evm, 0, child_evm.return_data, FALSE);
    let summary = EVM.finalize(child_evm);
    let evm = CallHelper.finalize_parent(summary);

    // Then
    let (stack, success) = Stack.peek(evm.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__exec_delegatecall__should_return_a_new_context_based_on_calling_evm_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Starknet.deploy(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    tempvar address = new Uint256(address_low, address_high);
    tempvar args_offset = new Uint256(3, 0);
    tempvar args_size = new Uint256(4, 0);
    tempvar ret_offset = new Uint256(5, 0);
    tempvar ret_size = new Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    tempvar memory_word = new Uint256(low=0, high=0x11223344556677880000000000000000);
    tempvar memory_offset = new Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let evm = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let evm = MemoryOperations.exec_mstore(evm);

    // When
    let child_evm = SystemOperations.exec_delegatecall(evm);

    // Then
    assert child_evm.message.bytecode_len = 0;
    assert child_evm.message.calldata_len = 4;
    assert [child_evm.message.calldata] = 0x44;
    assert [child_evm.message.calldata + 1] = 0x55;
    assert [child_evm.message.calldata + 2] = 0x66;
    assert [child_evm.message.calldata + 3] = 0x77;
    assert child_evm.message.value = 0;
    assert child_evm.program_counter = 0;
    assert child_evm.stopped = 0;
    assert child_evm.message.gas_price = 0;
    assert child_evm.message.address.starknet = evm.message.address.starknet;
    assert child_evm.message.address.evm = evm.message.address.evm;
    TestHelpers.assert_execution_context_equal(child_evm.message.parent, evm);

    // Fake a RETURN in child_evm then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the child_evm does set proper values for return_data_len and return_data
    let child_evm = EVM.stop(child_evm, 0, child_evm.return_data, FALSE);
    let summary = EVM.finalize(child_evm);
    let evm = CallHelper.finalize_parent(summary);

    // Then
    let (stack, success) = Stack.peek(evm.stack, 0);
    assert success.low = 1;

    return ();
}

@external
func test__get_create_address_should_construct_address_deterministically{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_caller_address: felt, nonce: felt, expected_create_address: felt) {
    let (evm_contract_address) = CreateHelper.get_create_address(evm_caller_address, nonce);

    assert evm_contract_address = expected_create_address;

    return ();
}

@external
func test__exec_create{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    opcode: felt,
    salt: felt,
    create_code_len: felt,
    create_code: felt*,
    value: felt,
    evm_caller_address: felt,
) -> (create_address: felt, nonce: felt) {
    alloc_locals;

    // Given
    let stack = Stack.init();
    let offset = 0;
    let stack = Stack.push_uint128(stack, salt);
    let stack = Stack.push_uint128(stack, create_code_len);
    let stack = Stack.push_uint128(stack, offset);
    let stack = Stack.push_uint128(stack, value);

    let memory = Memory.init();
    let memory = Memory.store_n(memory, create_code_len, create_code, offset);

    let bytecode_len = 1;
    let (bytecode: felt*) = alloc();
    assert [bytecode] = opcode;
    let (contract_address: felt) = Account.compute_starknet_address(evm_caller_address);
    let evm = TestHelpers.init_context_at_address(
        bytecode_len, bytecode, contract_address, evm_caller_address
    );
    let (state, account) = State.get_account(evm.state, evm.message.address);
    let evm = EVM.update_memory(evm, memory);
    let evm = EVM.update_stack(evm, stack);
    let evm = EVM.update_state(evm, state);
    let nonce = account.nonce;
    let balance_prev = account.balance;

    // When
    let child_evm = SystemOperations.exec_create(evm);

    // Then
    assert child_evm.message.calldata_len = 0;
    TestHelpers.assert_array_equal(
        child_evm.message.bytecode_len, child_evm.message.bytecode, create_code_len, create_code
    );
    assert child_evm.message.value = value;
    assert child_evm.program_counter = 0;
    assert child_evm.stopped = 0;
    assert child_evm.return_data_len = 0;
    assert child_evm.message.gas_price = evm.message.gas_price;
    assert_not_zero(child_evm.message.address.starknet);
    assert_not_zero(child_evm.message.address.evm);
    TestHelpers.assert_execution_context_equal(evm, child_evm.message.parent);

    // Fake a RETURN in child_evm then finalize
    let return_data_len = 65;
    memset(child_evm.return_data, 0xff, return_data_len);
    let child_evm = EVM.stop(child_evm, return_data_len, child_evm.return_data, FALSE);
    let summary = EVM.finalize(child_evm);
    let evm = CreateHelper.finalize_parent(summary);

    // Then
    let (state, account) = State.get_account(evm.state, child_evm.message.address);
    TestHelpers.assert_array_equal(
        account.code_len, account.code, return_data_len, child_evm.return_data
    );

    let (state, sender) = State.get_account(state, evm.message.address);
    assert balance_prev.low = value + sender.balance.low;
    assert [account.balance] = Uint256(value, 0);
    let (stack, address) = Stack.peek(evm.stack, 0);
    let evm_contract_address = uint256_to_uint160([address]);
    return (evm_contract_address, nonce);
}
