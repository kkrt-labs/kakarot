// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.interfaces.interfaces import IKakarot
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.constants import Constants, registry_address, evm_contract_class_hash
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.environmental_information import EnvironmentalInformation
from tests.unit.helpers.helpers import TestHelpers

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
    tempvar block_number: felt* = new (1);
    tempvar block_hash: felt* = new (1);
    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode,
        bytecode_len=bytecode_len,
        calldata=calldata,
        calldata_len=1,
        value=0,
        block_context=new model.BlockContext(1, block_number, 1, block_hash),
        );

    // Initialize ExecutionContext
    let (empty_return_data: felt*) = alloc();
    let stack: model.Stack* = Stack.init();
    let memory: model.Memory* = Memory.init();
    let gas_limit = Constants.TRANSACTION_GAS_LIMIT;
    let calling_context = ExecutionContext.init_empty();
    let sub_context = ExecutionContext.init_empty();

    local ctx: model.ExecutionContext* = new model.ExecutionContext(
        call_context=call_context,
        program_counter=0,
        stopped=FALSE,
        return_data=empty_return_data,
        return_data_len=0,
        stack=stack,
        memory=memory,
        gas_used=0,
        gas_limit=gas_limit,
        intrinsic_gas_cost=0,
        starknet_contract_address=0,
        evm_contract_address=420,
        calling_context=calling_context,
        sub_context=sub_context,
        );
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

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(420, 0);
    return ();
}

@external
func test__exec_extcodesize__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(account_registry_address: felt) {
    // Given
    alloc_locals;

    registry_address.write(account_registry_address);

    let bytecode_len = 0;
    let (bytecode) = alloc();
    let address = Uint256(0, 0);
    let stack = Stack.init();
    let stack = Stack.push(stack, address);

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
}(
    account_registry_address: felt,
    evm_contract_address: felt,
    size: felt,
    offset: felt,
    dest_offset: felt,
) -> (memory_len: felt, memory: felt*) {
    // Given
    alloc_locals;

    // make a deployed registry contract available
    registry_address.write(account_registry_address);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(size, 0));  // size
    let stack: model.Stack* = Stack.push(stack, Uint256(offset, 0));  // offset
    let stack: model.Stack* = Stack.push(stack, Uint256(dest_offset, 0));  // dest_offset
    let stack: model.Stack* = Stack.push(stack, Uint256(evm_contract_address, 0));  // address

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(ctx);

    // Then
    assert result.stack.len_16bytes = 0;

    let (output_array) = alloc();
    Memory.load_n(result.memory, size, output_array, dest_offset);

    return (memory_len=size, memory=output_array);
}

@external
func test__exec_extcodecopy__should_handle_address_with_no_code{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(account_registry_address: felt) {
    // Given
    alloc_locals;

    // make a deployed registry contract available
    registry_address.write(account_registry_address);

    let (bytecode) = alloc();
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));  // size
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));  // offset
    let stack: model.Stack* = Stack.push(stack, Uint256(32, 0));  // dest_offset
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));  // address

    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(0, bytecode, stack);

    // we are hardcoding an assumption of 'cold' address access, for now.
    // but the dynamic gas values of  `minimum_word_size` and `memory_expansion_cost`
    // are being tested
    let expected_gas = 2609;

    // When
    let result = EnvironmentalInformation.exec_extcodecopy(ctx);
    let (output_array) = alloc();
    Memory.load_n(result.memory, 3, output_array, 32);

    // Then
    // ensure stack is consumed/updated
    assert result.stack.len_16bytes = 0;

    assert result.gas_used = expected_gas;

    assert [output_array] = 0;
    assert [output_array + 1] = 0;
    assert [output_array + 2] = 0;

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
    // filling at return_data + 1 because first first felt is return_data offset
    TestHelpers.array_fill(return_data + 1, return_data_len, 0xFF);
    let child_ctx: model.ExecutionContext* = TestHelpers.init_context_with_return_data(
        0, bytecode, return_data_len, return_data
    );

    // Pushing parameters needed by RETURNDATACOPY in the stack
    // size: byte size to copy.
    // offset: byte offset in the return data from the last executed sub context to copy.
    // destOffset: byte offset in the memory where the result will be copied.
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(32, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack_and_sub_ctx(
        0, bytecode, stack, child_ctx
    );

    // When
    let result: model.ExecutionContext* = EnvironmentalInformation.exec_returndatacopy(ctx);

    // Then
    let (memory, data) = Memory.load(result.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );
    assert result.gas_used = 3;

    // Pushing parameters for another RETURNDATACOPY
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(31, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(32, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(result, stack);
    let ctx: model.ExecutionContext* = ExecutionContext.update_memory(ctx, memory);

    // When
    let result: model.ExecutionContext* = EnvironmentalInformation.exec_returndatacopy(ctx);

    // Then
    // check first 32 bytes
    let (memory, data) = Memory.load(result.memory, 0);
    assert_uint256_eq(
        data, Uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
    );
    // check 1 byte more at offset 32
    let (output_array) = alloc();
    Memory.load_n(memory, 1, output_array, 32);
    assert [output_array] = 0xFF;

    return ();
}
