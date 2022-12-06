// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import split_felt

// Local dependencies
from kakarot.interfaces.interfaces import IKakarot
from kakarot.library import Kakarot
from kakarot.constants import evm_contract_class_hash, registry_address
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper
from kakarot.constants import Constants
from tests.utils.utils import TestHelpers

@external
func test_exec_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(reason: felt) {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(reason, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    // Then
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(32, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    SystemOperations.exec_revert(ctx);
    return ();
}

@external
func test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_contract_class_hash_: felt, registry_address_: felt, kakarot_address: felt) {
    // Deploy another contract
    alloc_locals;
    let (bytecode) = alloc();
    local bytecode_len = 0;
    evm_contract_class_hash.write(evm_contract_class_hash_);
    registry_address.write(registry_address_);
    let (local evm_contract_address, local starknet_contract_address) = IKakarot.deploy(
        kakarot_address, bytecode_len, bytecode
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Uint256(0, 0);
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
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.intrinsic_gas_cost = 0;
    assert sub_ctx.starknet_contract_address = starknet_contract_address;
    assert sub_ctx.evm_contract_address = evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.parent_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.child_context, sub_ctx);

    return ();
}

@external
func test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_contract_class_hash_: felt, registry_address_: felt, kakarot_address: felt) {
    // Deploy another contract
    alloc_locals;
    let (bytecode) = alloc();
    local bytecode_len = 0;
    evm_contract_class_hash.write(evm_contract_class_hash_);
    registry_address.write(registry_address_);
    let (local evm_contract_address, local starknet_contract_address) = IKakarot.deploy(
        kakarot_address, bytecode_len, bytecode
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Uint256(0, 0);
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
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.intrinsic_gas_cost = 0;
    assert sub_ctx.starknet_contract_address = ctx.starknet_contract_address;
    assert sub_ctx.evm_contract_address = ctx.evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.parent_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.child_context, sub_ctx);

    return ();
}

@external
func test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_contract_class_hash_: felt, registry_address_: felt, kakarot_address: felt) {
    // Deploy another contract
    alloc_locals;
    let (bytecode) = alloc();
    local bytecode_len = 0;
    evm_contract_class_hash.write(evm_contract_class_hash_);
    registry_address.write(registry_address_);
    let (local evm_contract_address, local starknet_contract_address) = IKakarot.deploy(
        kakarot_address, bytecode_len, bytecode
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Uint256(0, 0);
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
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.intrinsic_gas_cost = 0;
    assert sub_ctx.starknet_contract_address = starknet_contract_address;
    assert sub_ctx.evm_contract_address = evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.parent_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.child_context, sub_ctx);

    return ();
}

@external
func test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_contract_class_hash_: felt, registry_address_: felt, kakarot_address: felt) {
    // Deploy another contract
    alloc_locals;
    let (bytecode) = alloc();
    local bytecode_len = 0;
    evm_contract_class_hash.write(evm_contract_class_hash_);
    registry_address.write(registry_address_);
    let (local evm_contract_address, local starknet_contract_address) = IKakarot.deploy(
        kakarot_address, bytecode_len, bytecode
    );

    // Fill the stack with input data
    let stack: model.Stack* = Stack.init();
    let gas = Uint256(0, 0);
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
    assert sub_ctx.gas_limit = 0;
    assert sub_ctx.intrinsic_gas_cost = 0;
    assert sub_ctx.starknet_contract_address = ctx.starknet_contract_address;
    assert sub_ctx.evm_contract_address = ctx.evm_contract_address;
    TestHelpers.assert_execution_context_equal(sub_ctx.parent_context, ctx);

    // Fake a RETURN in sub_ctx then teardow, see note in evm.codes:
    // If the size of the return data is not known, it can also be retrieved after the call with
    // the instructions RETURNDATASIZE and RETURNDATACOPY (since the Byzantium fork).
    // So it's expected that the RETURN of the sub_ctx does set proper values for return_data_len and return_data
    let sub_ctx = ExecutionContext.update_return_data(sub_ctx, 0, sub_ctx.return_data);
    let ctx = CallHelper.finalize_calling_context(sub_ctx);

    // Then
    let (stack, success) = Stack.peek(ctx.stack, 0);
    assert success.low = 1;
    TestHelpers.assert_execution_context_equal(ctx.child_context, sub_ctx);

    return ();
}
