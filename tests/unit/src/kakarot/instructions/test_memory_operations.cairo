// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_new, dict_read, dict_squash, dict_update, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.constants import Constants, registry_address
from kakarot.instructions.system_operations import CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test__exec_pc__should_update_after_incrementing{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(increment) {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    let ctx = ExecutionContext.increment_program_counter(ctx, increment);

    // When
    let result = MemoryOperations.exec_pc(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(increment - 1, 0);
    return ();
}

@external
func test__exec_pop_should_pop_an_item_from_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    // Given
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    let result = MemoryOperations.exec_pop(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq(index0, Uint256(1, 0));
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    // Given
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(0, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    local gas_used_before = ctx.gas_used;
    let result = MemoryOperations.exec_mload(ctx);
    local gas_used = result.gas_used - gas_used_before;

    // Then
    assert gas_used = 3;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq(index0, Uint256(1, 0));
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_memory_expansion{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    let test_offset = 16;
    // Given
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(test_offset, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    local gas_used_before = ctx.gas_used;
    let result = MemoryOperations.exec_mload(ctx);
    local gas_used = result.gas_used - gas_used_before;

    // Then
    assert gas_used = 6;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq(index0, Uint256(0, 1));
    assert result.memory.bytes_len = test_offset + 32;
    return ();
}

@external
func test__exec_sstore_jhnn{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(account_registry_address: felt, evm_contract_address: felt, registry_address_: felt) {
    // Given
    alloc_locals;
    registry_address.write(registry_address_);

    // Given a context initialized at an evm address
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

    CreateHelper.finalize_revert(
        ctx, ctx.revert_contract_state.dict_start, revert_contract_state_dict_end
    );

    let (squashed_dict_start, squashed_dict_end) = default_dict_finalize(
        ctx.revert_contract_state.dict_start, revert_contract_state_dict_end, 0
    );
    CreateHelper.finalize_revert(ctx, squashed_dict_start, squashed_dict_end);

    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    let test_offset = 684;
    // Given
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(test_offset, 0));
    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    let result = MemoryOperations.exec_mload(ctx);

    // Then
    assert result.gas_used = 73;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert_uint256_eq(index0, Uint256(0, 0));
    assert result.memory.bytes_len = test_offset + 32;
    return ();
}

@external
func test__exec_gas_should_return_remaining_gas{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);
    // Given
    let stack: model.Stack* = Stack.init();

    let ctx = ExecutionContext.update_stack(ctx, stack);

    // When
    local gas_used_before = ctx.gas_used;
    let result = MemoryOperations.exec_gas(ctx);
    local gas_used = result.gas_used - gas_used_before;

    // Then
    assert gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, actual_remaining_gas) = Stack.peek(result.stack, 0);
    let expected_remaining_gas = Constants.TRANSACTION_GAS_LIMIT - gas_used;
    let expected_remaining_gas_uint256 = Uint256(expected_remaining_gas, 0);
    assert_uint256_eq(actual_remaining_gas, expected_remaining_gas_uint256);
    return ();
}
