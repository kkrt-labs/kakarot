%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.evm import EVM
from kakarot.instructions.memory_operations import MemoryOperations
from tests.utils.helpers import TestHelpers

func test__exec_pc__should_return_evm_program_counter{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    local increment: felt;
    %{ ids.increment = program_input["increment"] %}

    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let evm = EVM.increment_program_counter(evm, increment);
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    // When
    with stack, memory, state {
        let evm = MemoryOperations.exec_pc(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert index0.low = increment;
    assert index0.high = 0;
    return ();
}

func test__exec_pop_should_pop_an_item_from_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(2, 0);

    // When
    with stack, memory, state {
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

func test__exec_mload_should_load_a_value_from_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    // When
    with stack, memory, state {
        Stack.push(item_1);
        Stack.push(item_0);

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

func test__exec_mload_should_load_a_value_from_memory_with_memory_expansion{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    with stack, memory, state {
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

func test__exec_mload_should_load_a_value_from_memory_with_offset_larger_than_msize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_with_bytecode(0, bytecode);
    let test_offset = 684;
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    tempvar item_1 = new Uint256(1, 0);
    tempvar item_0 = new Uint256(0, 0);

    with stack, memory, state {
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

func test__exec_mcopy_should_copy_a_value_from_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    // Stack items for mcopy
    tempvar size_mcopy = new Uint256(0x20, 0);
    tempvar offset_mcopy = new Uint256(0, 0);
    tempvar dst_offset_mcopy = new Uint256(0x20, 0);
    // Stack items for mstore
    tempvar value_mstore = new Uint256(0x1, 0);
    tempvar dst_offset_mstore = new Uint256(0, 0);

    with stack, memory, state {
        // store 1 at offset 0
        Stack.push(value_mstore);
        Stack.push(dst_offset_mstore);
        let evm = MemoryOperations.exec_mstore(evm);

        // copy 1 from offset 0 to offset 0x20
        Stack.push(size_mcopy);
        Stack.push(offset_mcopy);
        Stack.push(dst_offset_mcopy);
        let evm = MemoryOperations.exec_mcopy(evm);

        // load from offset 0x20
        Stack.push(dst_offset_mcopy);
        let evm = MemoryOperations.exec_mload(evm);

        let (index0) = Stack.peek(0);
    }
    assert stack.size = 1;
    assert_uint256_eq([index0], Uint256(0x1, 0));
    return ();
}

func test__exec_mcopy_should_fail_if_memory_expansion_to_large{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.EVM* {
    alloc_locals;
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    // Stack items for mcopy
    tempvar size_mcopy = new Uint256(0x20, 0);
    tempvar offset_mcopy = new Uint256(0, 0);
    tempvar dst_offset_mcopy = new Uint256(0, 1);
    // Stack items for mstore
    tempvar value_mstore = new Uint256(0x1, 0);
    tempvar dst_offset_mstore = new Uint256(0, 0);

    with stack, memory, state {
        // store 1 at offset 0
        Stack.push(value_mstore);
        Stack.push(dst_offset_mstore);
        let evm = MemoryOperations.exec_mstore(evm);

        // copy 1 from offset 0 to offset 0x20
        Stack.push(size_mcopy);
        Stack.push(offset_mcopy);
        Stack.push(dst_offset_mcopy);
        let evm = MemoryOperations.exec_mcopy(evm);
    }
    return evm;
}
