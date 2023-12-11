// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.evm import EVM
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.constants import Constants
from tests.utils.helpers import TestHelpers

@external
func test__exec_pc__should_update_after_incrementing{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(increment) {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let evm = EVM.increment_program_counter(evm, increment);
    let stack = Stack.init();
    let memory = Memory.init();

    // When
    with stack, memory {
        let evm = MemoryOperations.exec_pc(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert index0.low = increment;
    assert index0.high = 0;
    return ();
}

@external
func test__exec_pop_should_pop_an_item_from_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(2, 0);

    // When
    with stack, memory {
        Stack.push(item_1);
        Stack.push(item_0);

        let evm = MemoryOperations.exec_pop(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert_uint256_eq([index0], Uint256(1, 0));
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    // When
    with stack, memory {
        Stack.push(stack, item_1);
        Stack.push(stack, item_0);

        let evm = MemoryOperations.exec_mstore(evm);

        Stack.push(item_0);

        let evm = MemoryOperations.exec_mload(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert_uint256_eq([index0], [item_1]);
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_memory_expansion{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let memory = Memory.init();

    with stack, memory {
        tempvar item_1 = new Uint256(1, 0);
        tempvar item_0 = new Uint256(0, 0);

        Stack.push(item_1);
        Stack.push(item_0);

        let evm = MemoryOperations.exec_mstore(evm);

        tempvar offset = new Uint256(16, 0);
        Stack.push(offset);

        let evm = MemoryOperations.exec_mload(evm);
        let (index0) = Stack.peek(0);
    }

    assert stack.size = 1;
    assert_uint256_eq([index0], Uint256(0, 1));
    assert memory.words_len = 2;
    return ();
}

@external
func test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let test_offset = 684;
    // Given
    let stack = Stack.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    with stack, memory {
        Stack.push(item_1);
        Stack.push(item_0);

        let evm = MemoryOperations.exec_mstore(evm);
        tempvar offset = new Uint256(test_offset, 0);
        Stack.push(offset);

        let evm = MemoryOperations.exec_mload(evm);

        let (index0) = Stack.peek(0);
    }
    assert stack.size = 1;
    assert_uint256_eq([index0], Uint256(0, 0));
    assert memory.words_len = 23;
    return ();
}
