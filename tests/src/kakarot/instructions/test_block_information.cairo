// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub, assert_uint256_eq
from starkware.cairo.common.math import assert_nn
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.registers import get_fp_and_pc

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants, blockhash_registry_address
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.block_information import BlockInformation
from tests.utils.helpers import TestHelpers

// Storage for testing BLOCKHASH
@storage_var
func block_number() -> (block_number: Uint256) {
}

@storage_var
func blockhash() -> (blockhash: felt) {
}

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(block_number_: Uint256, blockhash_: felt, blockhash_registry_address_: felt) {
    block_number.write(block_number_);
    blockhash.write(blockhash_);
    blockhash_registry_address.write(blockhash_registry_address_);
    return ();
}

@view
func test__blockhash_should_push_blockhash_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given # 1
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;

    let (bytecode) = alloc();
    let stack = Stack.init();

    let (local block_number_: Uint256) = block_number.read();

    let stack = Stack.push(stack, &block_number_);
    let ctx = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = BlockInformation.exec_blockhash(ctx);

    // Then
    assert result.gas_used = 20;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let (blockhash_) = blockhash.read();
    let value = Helpers.to_uint256(val=blockhash_);
    assert_uint256_eq([index0], [value]);

    // Given # 2
    let (bytecode) = alloc();
    let stack = Stack.init();

    let (current_block_number: felt) = get_block_number();
    let out_of_range_block = current_block_number - 260;
    assert_nn(out_of_range_block);
    let out_of_range_block_uint256 = Helpers.to_uint256(val=out_of_range_block);
    let stack = Stack.push(stack, out_of_range_block_uint256);
    let ctx = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = BlockInformation.exec_blockhash(ctx);

    // Then
    assert result.gas_used = 20;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 0;
    assert index0.high = 0;

    return ();
}

@view
func test__chainId__should_push_chain_id_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_chainid(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0.low = 1263227476;
    assert index0.high = 0;
    return ();
}

@external
func test__coinbase_should_push_coinbase_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_coinbase(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let coinbase_address = Helpers.to_uint256(Constants.MOCK_COINBASE_ADDRESS);
    assert_uint256_eq([index0], [coinbase_address]);
    return ();
}

@external
func test__timestamp_should_push_block_timestamp_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_timestamp(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let (current_timestamp) = get_block_timestamp();
    let block_timestamp = Helpers.to_uint256(current_timestamp);
    assert_uint256_eq([index0], [block_timestamp]);
    return ();
}

@external
func test__number_should_push_block_number_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_number(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let (current_block) = get_block_number();
    let block_number = Helpers.to_uint256(current_block);
    assert_uint256_eq([index0], [block_number]);
    return ();
}

@external
func test__gaslimit_should_push_gaslimit_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_gaslimit(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let gas_limit = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    assert_uint256_eq([index0], [gas_limit]);
    return ();
}

@external
func test__difficulty_should_push_difficulty_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_difficulty(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let difficulty = Helpers.to_uint256(0);
    assert_uint256_eq([index0], [difficulty]);
    return ();
}

@external
func test__basefee_should_push_basefee_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let ctx = TestHelpers.init_context(0, bytecode);

    // When
    let result = BlockInformation.exec_basefee(ctx);

    // Then
    assert result.gas_used = 2;
    assert result.stack.size = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    let basefee = Helpers.to_uint256(0);
    assert_uint256_eq([index0], [basefee]);
    return ();
}
