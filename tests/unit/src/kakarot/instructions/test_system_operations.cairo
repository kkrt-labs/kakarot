// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import deploy, get_contract_address
from starkware.cairo.common.math import split_felt, assert_not_zero, assert_le

// Third party dependencies
from openzeppelin.token.erc20.library import ERC20

// Local dependencies
from kakarot.constants import (
    Constants,
    native_token_address,
    contract_account_class_hash,
    account_proxy_class_hash,
    salt,
)
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import (
    SystemOperations,
    CallHelper,
    CreateHelper,
    SelfDestructHelper,
)
from kakarot.interfaces.interfaces import IContractAccount, IKakarot, IAccount
from kakarot.library import Kakarot
from kakarot.accounts.library import Accounts
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from tests.unit.helpers.helpers import TestHelpers
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

@external
func test__exec_return_should_return_context_with_updated_return_data{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(return_data: felt) {
    // Given
    alloc_locals;
    let bytecode: felt* = alloc();
    let stack: model.Stack* = Stack.init();

    // When
    let stack: model.Stack* = Stack.push(stack, Uint256(return_data, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    // Then
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(32, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = SystemOperations.exec_return(ctx);

    // Then
    let returned_data = Helpers.load_word(32, ctx.return_data);
    assert return_data = returned_data;

    return ();
}

@external
func test__exec_revert_callhelper_calling_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    reason_low: felt,
    reason_high: felt,
    size: felt,
    account_registry_address: felt,
    evm_contract_address: felt,
    registry_address_: felt,
) -> (reason: Uint256) {
    // Given
    alloc_locals;

    registry_address.write(registry_address_);

    let calling_context = ExecutionContext.init_empty();
    let ctx = ExecutionContext.init_at_address(
        evm_contract_address, 10000, 0, cast(0, felt*), 0, calling_context, 0, cast(0, felt*), 0
    );

    let key = 1;
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(3, 0));  // value
    let stack: model.Stack* = Stack.push(stack, Uint256(key, 0));  // key
    let ctx = ExecutionContext.update_stack(ctx, stack);
    let ctx = MemoryOperations.exec_sstore(ctx);

    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(4, 0));  // value
    let stack: model.Stack* = Stack.push(stack, Uint256(key, 0));  // key
    let ctx = ExecutionContext.update_stack(ctx, stack);
    let ctx = MemoryOperations.exec_sstore(ctx);

    // When
    let revert_contract_state_dict_end = ctx.revert_contract_state.dict_end;
    %{ print(f"{ids.revert_contract_state_dict_end=} {ids.ctx.revert_contract_state=}") %}

    let reason_uint256 = Uint256(low=reason_low, high=reason_high);
    local offset: Uint256 = Uint256(32, 0);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, reason_uint256);  // value
    let stack: model.Stack* = Stack.push(stack, offset);  // offset
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(0, 0));  // offset is 0 to have the reason at 0x20
    let stack: model.Stack* = Stack.push(stack, Uint256(size, 0));  // size
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);

    // When
    let ctx = SystemOperations.exec_revert(ctx);
    let ctx = CallHelper.finalize_calling_context(ctx);

    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 0;

    // Then
    // TODO: update test when revert does not break the execution

    return (reason=Uint256(10, 10));
}

func test__exec_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(reason_low: felt, reason_high: felt, size: felt) {
    // Given
    alloc_locals;
    let reason_uint256 = Uint256(low=reason_low, high=reason_high);
    local offset: Uint256 = Uint256(32, 0);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, reason_uint256);  // value
    let stack: model.Stack* = Stack.push(stack, offset);  // offset
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(0, 0));  // offset is 0 to have the reason at 0x20
    let stack: model.Stack* = Stack.push(stack, Uint256(size, 0));  // size
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);

    // When
    let ctx = SystemOperations.exec_revert(ctx);

    // Then
    // TODO: update test when revert does not break the execution

    return ();
}

@external
func test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy an empty contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Accounts.create(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    let address = Uint256(address_low, address_high);
    tempvar value = Uint256(2, 0);
    let args_offset = Uint256(3, 0);
    let args_size = Uint256(4, 0);
    tempvar ret_offset = Uint256(5, 0);
    tempvar ret_size = Uint256(6, 0);
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
    let memory_word = Uint256(low=0, high=22774453838368691922685013100469420032);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_call(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = bytecode_len;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = ret_size.low;
    assert [sub_ctx.return_data] = ret_offset.low;
    assert sub_ctx.gas_used = 0;
    let (gas_felt, _) = Helpers.div_rem(Constants.TRANSACTION_GAS_LIMIT, 64);
    assert_le(sub_ctx.gas_limit, gas_felt);
    assert sub_ctx.gas_price = 0;
    assert sub_ctx.starknet_contract_address = starknet_contract_address;
    assert sub_ctx.evm_contract_address = evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);

    return ();
}

@external
func test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Accounts.create(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    let address = Uint256(address_low, address_high);
    tempvar value = Uint256(2, 0);
    let args_offset = Uint256(3, 0);
    let args_size = Uint256(4, 0);
    tempvar ret_offset = Uint256(5, 0);
    tempvar ret_size = Uint256(6, 0);
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
    let memory_word = Uint256(low=0, high=22774453838368691922685013100469420032);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_callcode(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = ret_size.low;
    assert [sub_ctx.return_data] = ret_offset.low;
    assert sub_ctx.gas_used = 0;
    let (gas_felt, _) = Helpers.div_rem(Constants.TRANSACTION_GAS_LIMIT, 64);
    assert_le(sub_ctx.gas_limit, gas_felt);
    assert sub_ctx.gas_price = 0;
    assert sub_ctx.starknet_contract_address = ctx.starknet_contract_address;
    assert sub_ctx.evm_contract_address = ctx.evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);

    return ();
}

@external
func test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Accounts.create(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    let address = Uint256(address_low, address_high);
    let args_offset = Uint256(3, 0);
    let args_size = Uint256(4, 0);
    tempvar ret_offset = Uint256(5, 0);
    tempvar ret_size = Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    let memory_word = Uint256(low=0, high=22774453838368691922685013100469420032);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_staticcall(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = 0;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = ret_size.low;
    assert [sub_ctx.return_data] = ret_offset.low;
    assert sub_ctx.gas_used = 0;
    let (gas_felt, _) = Helpers.div_rem(Constants.TRANSACTION_GAS_LIMIT, 64);
    assert_le(sub_ctx.gas_limit, gas_felt);
    assert sub_ctx.gas_price = 0;
    assert sub_ctx.starknet_contract_address = starknet_contract_address;
    assert sub_ctx.evm_contract_address = evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);

    return ();
}

@external
func test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Deploy another contract
    alloc_locals;

    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Accounts.create(
        contract_account_class_hash_, evm_contract_address
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(evm_contract_address);
    let address = Uint256(address_low, address_high);
    let args_offset = Uint256(3, 0);
    let args_size = Uint256(4, 0);
    tempvar ret_offset = Uint256(5, 0);
    tempvar ret_size = Uint256(6, 0);
    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);
    // Put some value in memory as it is used for calldata with args_size and args_offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // calldata should be 0x 44 55 66 77
    let memory_word = Uint256(low=0, high=22774453838368691922685013100469420032);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let (bytecode) = alloc();
    local bytecode_len = 0;
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_delegatecall(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 0;
    assert sub_ctx.call_context.calldata_len = 4;
    assert [sub_ctx.call_context.calldata] = 0x44;
    assert [sub_ctx.call_context.calldata + 1] = 0x55;
    assert [sub_ctx.call_context.calldata + 2] = 0x66;
    assert [sub_ctx.call_context.calldata + 3] = 0x77;
    assert sub_ctx.call_context.value = 0;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = ret_size.low;
    assert [sub_ctx.return_data] = ret_offset.low;
    assert sub_ctx.gas_used = 0;
    let (gas_felt, _) = Helpers.div_rem(Constants.TRANSACTION_GAS_LIMIT, 64);
    assert_le(sub_ctx.gas_limit, gas_felt);
    assert sub_ctx.gas_price = 0;
    assert sub_ctx.starknet_contract_address = ctx.starknet_contract_address;
    assert sub_ctx.evm_contract_address = ctx.evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.calling_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);

    return ();
}
@external
func test__exec_create__should_return_a_new_context_with_bytecode_from_memory_at_expected_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_caller_address: felt, salt_: felt, expected_create_address: felt) {
    alloc_locals;

    salt.write(salt_);

    // Fill the stack with exec_create args
    let stack: model.Stack* = Stack.init();
    tempvar value = Uint256(1, 0);
    let offset = Uint256(3, 0);
    let size = Uint256(4, 0);
    let stack = Stack.push(stack, size);
    let stack = Stack.push(stack, offset);
    let stack = Stack.push(stack, value);

    // Put some value in memory as it is used for bytecode with size and offset
    // Word is 0x 11 22 33 44 55 66 77 88 00 00 ... 00
    // bytecode should be 0x 44 55 66 77
    let memory_word = Uint256(low=0, high=22774453838368691922685013100469420032);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let bytecode_len = 0;
    let (bytecode: felt*) = alloc();
    let ctx = TestHelpers.init_context_at_address_with_stack(
        evm_caller_address, bytecode_len, bytecode, stack
    );

    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_create(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 4;
    assert sub_ctx.call_context.calldata_len = 0;
    assert [sub_ctx.call_context.bytecode] = 0x44;
    assert [sub_ctx.call_context.bytecode + 1] = 0x55;
    assert [sub_ctx.call_context.bytecode + 2] = 0x66;
    assert [sub_ctx.call_context.bytecode + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.gas_price = 0;
    assert_not_zero(sub_ctx.starknet_contract_address);
    assert_not_zero(sub_ctx.evm_contract_address);
    let (sub_ctx_contract_stored_bytecode) = IAccount.bytecode_len(
        sub_ctx.starknet_contract_address
    );
    assert sub_ctx_contract_stored_bytecode = 0;
    TestHelpers.assert_execution_context_equal(ctx, sub_ctx.calling_context);

    // Fake a RETURN in sub_ctx then finalize
    let return_data_len = 65;
    TestHelpers.array_fill(sub_ctx.return_data, return_data_len, 0xff);
    let sub_ctx = ExecutionContext.update_return_data(
        sub_ctx, return_data_len, sub_ctx.return_data
    );
    let ctx = CreateHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, address) = Stack.peek(ctx.stack, 0);
    let evm_contract_address = Helpers.uint256_to_felt(address);
    assert evm_contract_address = sub_ctx.evm_contract_address;
    assert sub_ctx.evm_contract_address = expected_create_address;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);
    let (created_contract_bytecode_len, created_contract_bytecode) = IAccount.bytecode(
        sub_ctx.starknet_contract_address
    );
    TestHelpers.assert_array_equal(
        created_contract_bytecode_len,
        created_contract_bytecode,
        return_data_len,
        sub_ctx.return_data,
    );

    return ();
}

@external
func test__exec_create2__should_return_a_new_context_with_bytecode_from_memory_at_expected_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    evm_caller_address: felt,
    bytecode_offset: Uint256,
    bytecode_size: Uint256,
    salt: Uint256,
    memory_word: Uint256,
    expected_create2_address: felt,
) {
    alloc_locals;

    // Fill the stack with exec_create2 args
    let stack: model.Stack* = Stack.init();
    tempvar value = Uint256(1, 0);
    let offset = bytecode_offset;
    let size = bytecode_size;
    let salt = salt;
    let stack = Stack.push(stack, salt);
    let stack = Stack.push(stack, size);
    let stack = Stack.push(stack, offset);
    let stack = Stack.push(stack, value);

    // Put some value in memory as it is used for byte
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, memory_word);
    let stack = Stack.push(stack, memory_offset);
    let bytecode_len = 0;
    let (bytecode: felt*) = alloc();
    let ctx = TestHelpers.init_context_at_address_with_stack(
        evm_caller_address, bytecode_len, bytecode, stack
    );

    assert ctx.evm_contract_address = evm_caller_address;
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let sub_ctx = SystemOperations.exec_create2(ctx);

    // Then
    assert sub_ctx.call_context.bytecode_len = 4;
    assert sub_ctx.call_context.calldata_len = 0;
    assert [sub_ctx.call_context.bytecode] = 0x44;
    assert [sub_ctx.call_context.bytecode + 1] = 0x55;
    assert [sub_ctx.call_context.bytecode + 2] = 0x66;
    assert [sub_ctx.call_context.bytecode + 3] = 0x77;
    assert sub_ctx.call_context.value = value.low;
    assert sub_ctx.program_counter = 0;
    assert sub_ctx.stopped = 0;
    assert sub_ctx.return_data_len = 0;
    assert sub_ctx.gas_used = 0;
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.gas_price = 0;
    assert_not_zero(sub_ctx.starknet_contract_address);
    assert_not_zero(sub_ctx.evm_contract_address);
    let (sub_ctx_contract_stored_bytecode) = IAccount.bytecode_len(
        sub_ctx.starknet_contract_address
    );
    assert sub_ctx_contract_stored_bytecode = 0;
    TestHelpers.assert_execution_context_equal(ctx, sub_ctx.calling_context);

    // Fake a RETURN in sub_ctx then finalize
    let return_data_len = 65;
    TestHelpers.array_fill(sub_ctx.return_data, return_data_len, 0xff);
    let sub_ctx = ExecutionContext.update_return_data(
        sub_ctx, return_data_len, sub_ctx.return_data
    );
    let ctx = CreateHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, address) = Stack.peek(ctx.stack, 0);
    let evm_contract_address = Helpers.uint256_to_felt(address);
    assert evm_contract_address = sub_ctx.evm_contract_address;
    assert sub_ctx.evm_contract_address = expected_create2_address;
    TestHelpers.assert_execution_context_equal(ctx.sub_context, sub_ctx);
    let (created_contract_bytecode_len, created_contract_bytecode) = IAccount.bytecode(
        sub_ctx.starknet_contract_address
    );
    TestHelpers.assert_array_equal(
        created_contract_bytecode_len,
        created_contract_bytecode,
        return_data_len,
        sub_ctx.return_data,
    );

    return ();
}

@external
func test__exec_selfdestruct__should_delete_account_bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) {
    alloc_locals;
    native_token_address.write(evm_address);

    // Create sub_ctx writing directly in memory because need to update calling_context
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let memory: model.Memory* = Memory.init();
    let (bytecode) = alloc();
    let (return_data) = alloc();
    assert [return_data] = 0;
    assert [return_data + 1] = 10;
    let (destroy_contracts) = alloc();
    let (calldata) = alloc();
    assert [calldata] = '';
    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode, bytecode_len=0, calldata=calldata, calldata_len=1, value=0
    );
    let stack = Stack.push(stack, Uint256(10, 0));
    let (sub_ctx: felt*) = alloc();
    assert [sub_ctx] = cast(call_context, felt);  // call_context
    assert [sub_ctx + 1] = 0;  // program_counter
    assert [sub_ctx + 2] = 0;  // stopped
    assert [sub_ctx + 3] = cast(return_data + 1, felt);  // return_data
    assert [sub_ctx + 4] = 1;  // return_data_len
    assert [sub_ctx + 5] = cast(stack, felt);  // stack
    assert [sub_ctx + 6] = cast(memory, felt);  // memory
    assert [sub_ctx + 7] = 0;  // gas_used
    assert [sub_ctx + 8] = 0;  // gas_limit
    assert [sub_ctx + 9] = 0;  // intrinsic_gas_cost
    assert [sub_ctx + 13] = 0;  // sub_context
    assert [sub_ctx + 14] = 0;  // destroy_contracts_len
    assert [sub_ctx + 15] = cast(destroy_contracts, felt);  // destroy_contracts
    assert [sub_ctx + 16] = 0;  // read only

    // Simulate contract creation
    let (contract_account_class_hash_) = contract_account_class_hash.read();
    let (evm_contract_address) = CreateHelper.get_create_address(0, 0);
    let (local starknet_contract_address) = Accounts.create(
        contract_account_class_hash_, evm_contract_address
    );
    assert [sub_ctx + 10] = starknet_contract_address;  // starknet_contract_address
    assert [sub_ctx + 11] = evm_contract_address;  // evm_contract_address

    // Fill contract bytecode
    let (bytecode) = alloc();
    assert [bytecode] = 1907;
    IContractAccount.write_bytecode(
        contract_address=starknet_contract_address, bytecode_len=1, bytecode=bytecode
    );

    // Create context
    let stack: model.Stack* = Stack.init();
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context_with_stack_and_sub_ctx(
        0, bytecode, stack, cast(sub_ctx, model.ExecutionContext*)
    );
    assert [sub_ctx + 12] = cast(ctx, felt);  // calling_context

    let sub_ctx_object: model.ExecutionContext* = cast(sub_ctx, model.ExecutionContext*);

    // When
    let sub_ctx_object: model.ExecutionContext* = SystemOperations.exec_selfdestruct(
        sub_ctx_object
    );

    // Simulate run
    let ctx = CallHelper.finalize_calling_context(sub_ctx_object);
    let ctx = SelfDestructHelper.finalize(ctx);

    // Then
    let (evm_contract_byte_len) = IAccount.bytecode_len(contract_address=starknet_contract_address);

    assert evm_contract_byte_len = 0;
    return ();
}
