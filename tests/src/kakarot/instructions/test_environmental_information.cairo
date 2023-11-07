// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt
from starkware.starknet.common.syscalls import get_contract_address

// Third party dependencies
from openzeppelin.token.erc20.library import ERC20

// Local dependencies
from kakarot.account import Account
from kakarot.constants import Constants
from kakarot.storages import (
    contract_account_class_hash,
    account_proxy_class_hash,
    native_token_address,
)
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IKakarot, IContractAccount
from kakarot.library import Kakarot
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(contract_account_class_hash_: felt, account_proxy_class_hash_) {
    account_proxy_class_hash.write(account_proxy_class_hash_);
    contract_account_class_hash.write(contract_account_class_hash_);
    let (contract_address: felt) = get_contract_address();
    native_token_address.write(contract_address);
    return ();
}

// @dev The contract account initialization includes a call to the Kakarot contract
// in order to get the native token address. As the Kakarot contract is not deployed within this test, we make a call to this contract instead.
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    return Kakarot.get_native_token();
}

// @dev The contract account initialization includes a call to an ERC20 contract to set an infitite transfer allowance to Kakarot.
// As the ERC20 contract is not deployed within this test, we make a call to this contract instead.
@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

func init_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.ExecutionContext* {
    alloc_locals;

    // Initialize CallContext
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';
    let calling_context = ExecutionContext.init_empty();
    tempvar address = new model.Address(0, 420);
    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode,
        bytecode_len=bytecode_len,
        calldata=calldata,
        calldata_len=1,
        value=0,
        gas_limit=Constants.TRANSACTION_GAS_LIMIT,
        gas_price=0,
        origin=address,
        calling_context=calling_context,
        address=address,
        read_only=FALSE,
        is_create=FALSE,
    );

    // Initialize ExecutionContext
    let ctx = ExecutionContext.init(call_context);
    return ctx;
}

@view
func test__exec_address__should_push_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let ctx: model.ExecutionContext* = init_context();

    // When
    let result = EnvironmentalInformation.exec_address(ctx);

    // The
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 420;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_extcodesize__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    let address = Helpers.to_uint256(evm_contract_address);

    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let bytecode_len = 0;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    // When
    let ctx = EnvironmentalInformation.exec_extcodesize(ctx);

    // Then
    let (stack, extcodesize) = Stack.peek(ctx.stack, 0);
    assert extcodesize.low = 0;
    assert extcodesize.high = 0;

    return ();
}

@external
func test__exec_extcodecopy__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, size: felt, offset: felt, dest_offset: felt) -> (
    memory_len: felt, memory: felt*
) {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    IContractAccount.write_bytecode(starknet_contract_address, bytecode_len, bytecode);
    let evm_contract_address_uint256 = Helpers.to_uint256(evm_contract_address);

    // make a deployed registry contract available
    tempvar item_3 = new Uint256(size, 0);  // size
    tempvar item_2 = new Uint256(offset, 0);  // offset
    tempvar item_1 = new Uint256(dest_offset, 0);  // dest_offset
    tempvar item_0 = evm_contract_address_uint256;  // address

    let stack = Stack.init();
    let stack = Stack.push(stack, item_3);  // size
    let stack = Stack.push(stack, item_2);  // offset
    let stack = Stack.push(stack, item_1);  // dest_offset
    let stack = Stack.push(stack, item_0);  // address

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    // we are hardcoding an assumption of 'cold' address access, for now.
    let address_access_cost = 2600;
    let (minimum_word_size) = Helpers.minimum_word_count(size);
    let (_, memory_expansion_cost) = Memory.ensure_length(
        self=ctx.memory, length=dest_offset + size
    );

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(ctx);

    // Then
    assert result.stack.size = 0;

    let (output_array) = alloc();
    Memory._load_n(result.memory, size, output_array, dest_offset);

    return (memory_len=size, memory=output_array);
}

@external
func test__exec_extcodecopy__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    // make a deployed registry contract available

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    let evm_contract_address_uint256 = Helpers.to_uint256(evm_contract_address);

    tempvar item_3 = new Uint256(3, 0);  // size
    tempvar item_2 = new Uint256(1, 0);  // offset
    tempvar item_1 = new Uint256(32, 0);  // dest_offset
    tempvar item_0 = evm_contract_address_uint256;  // address

    let stack = Stack.init();
    let stack = Stack.push(stack, item_3);  // size
    let stack = Stack.push(stack, item_2);  // offset
    let stack = Stack.push(stack, item_1);  // dest_offset
    let stack = Stack.push(stack, item_0);  // address

    let (bytecode) = alloc();
    let bytecode_len = 0;

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    // we are hardcoding an assumption of 'cold' address access, for now.
    // but the dynamic gas values of  `minimum_word_size` and `memory_expansion_cost`
    // are being tested
    let expected_gas = 2609;

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(ctx);
    let (output_array) = alloc();
    Memory._load_n(result.memory, 3, output_array, 32);

    // Then
    // ensure stack is consumed/updated
    assert result.stack.size = 0;

    assert [output_array] = 0;
    assert [output_array + 1] = 0;
    assert [output_array + 2] = 0;

    return ();
}

@external
func test__exec_gasprice{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let stack = Stack.init();
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    let expected_gas_price_uint256 = Helpers.to_uint256(ctx.call_context.gas_price);

    let result = EnvironmentalInformation.exec_gasprice(ctx);
    let (stack, gasprice) = Stack.peek(result.stack, 0);

    // The
    assert_uint256_eq([gasprice], [expected_gas_price_uint256]);

    return ();
}

@view
func test__returndatacopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    let (return_data) = alloc();
    let return_data_len: felt = 32;

    TestHelpers.array_fill(return_data, return_data_len, 0xFF);
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_return_data(
        0, bytecode, return_data_len, return_data
    );

    // Pushing parameters needed by RETURNDATACOPY in the stack
    // size: byte size to copy.
    // offset: byte offset in the return data from the last executed sub context to copy.
    // destOffset: byte offset in the memory where the result will be copied.
    tempvar item_2 = new Uint256(32, 0);
    tempvar item_1 = new Uint256(0, 0);
    tempvar item_0 = new Uint256(0, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    let ctx: model.ExecutionContext* = EnvironmentalInformation.exec_returndatacopy(ctx);

    // Then
    let (memory, data) = Memory._load(ctx.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );

    // Pushing parameters for another RETURNDATACOPY
    tempvar item_2 = new Uint256(1, 0);
    tempvar item_1 = new Uint256(31, 0);
    tempvar item_0 = new Uint256(32, 0);

    let stack = Stack.init();
    let stack = Stack.push(stack, item_2);
    let stack = Stack.push(stack, item_1);
    let stack = Stack.push(stack, item_0);

    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = ExecutionContext.update_memory(ctx, memory);

    // When
    let result: model.ExecutionContext* = EnvironmentalInformation.exec_returndatacopy(ctx);

    // Then
    // check first 32 bytes
    let (memory, data) = Memory._load(result.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );
    // check 1 byte more at offset 32
    let (output_array) = alloc();
    Memory._load_n(memory, 1, output_array, 32);
    assert [output_array] = 0xFF;

    return ();
}

@external
func test__exec_extcodehash__should_handle_invalid_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let bytecode_len = 0;
    let (bytecode) = alloc();
    tempvar address = new Uint256(0xDEAD, 0);
    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    // When
    let result = EnvironmentalInformation.exec_extcodehash(ctx);

    // Then
    let (stack, extcodehash) = Stack.peek(result.stack, 0);
    assert extcodehash.low = 0;
    assert extcodehash.high = 0;

    return ();
}

@external
func test__exec_extcodehash__should_handle_address_with_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, expected_hash_low: felt, expected_hash_high: felt) {
    // Given
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Account.deploy(
        contract_account_class_hash_, evm_contract_address
    );
    IContractAccount.write_bytecode(starknet_contract_address, bytecode_len, bytecode);
    let address = Helpers.to_uint256(evm_contract_address);
    let stack = Stack.init();
    let stack = Stack.push(stack, address);

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );

    // When
    let result = EnvironmentalInformation.exec_extcodehash(ctx);

    // Then
    let (stack, extcodehash) = Stack.peek(result.stack, 0);
    assert extcodehash.low = expected_hash_low;
    assert extcodehash.high = expected_hash_high;

    return ();
}
