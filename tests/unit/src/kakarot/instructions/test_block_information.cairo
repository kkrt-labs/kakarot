// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.block_information import BlockInformation
from tests.unit.helpers.helpers import TestHelpers

@view
func test__blockhash_should_push_blockhash_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given # 1
    alloc_locals;
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(503595, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = BlockInformation.exec_blockhash(ctx);

    // Then
    assert result.gas_used = 20;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(123, 0);

    // Given # 2
    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();

    let stack: model.Stack* = Stack.push(stack, Uint256(10, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = BlockInformation.exec_blockhash(ctx);

    // Then
    assert result.gas_used = 20;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(0, 0);

    return ();
}

@view
func test__chainId__should_push_chain_id_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_chainid(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(1263227476, 0);
    return ();
}

@external
func test__coinbase_should_push_coinbase_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_coinbase(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let coinbase_address = Helpers.to_uint256(Constants.MOCK_COINBASE_ADDRESS);
    assert index0 = coinbase_address;
    return ();
}

@external
func test__timestamp_should_push_block_timestamp_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_timestamp(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let (current_timestamp) = get_block_timestamp();
    let block_timestamp = Helpers.to_uint256(current_timestamp);
    assert index0 = block_timestamp;
    return ();
}

@external
func test__number_should_push_block_number_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_number(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let (current_block) = get_block_number();
    let block_number = Helpers.to_uint256(current_block);
    assert index0 = block_number;
    return ();
}

@external
func test__gaslimit_should_push_gaslimit_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_gaslimit(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let gas_limit = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    assert index0 = gas_limit;
    return ();
}

@external
func test__difficulty_should_push_difficulty_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_difficulty(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let difficulty = Helpers.to_uint256(0);
    assert index0 = difficulty;
    return ();
}

@external
func test__basefee_should_push_basefee_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx: model.ExecutionContext* = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_basefee(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let basefee = Helpers.to_uint256(0);
    assert index0 = basefee;
    return ();
}
