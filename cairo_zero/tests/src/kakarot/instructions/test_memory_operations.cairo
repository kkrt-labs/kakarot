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

func test__exec_mcopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.EVM*, model.Memory*) {
    alloc_locals;
    let (memory_init_state) = alloc();
    local memory_init_state_len: felt;
    let (size_mcopy_ptr) = alloc();
    let (src_offset_mcopy_ptr) = alloc();
    let (dst_offset_mcopy_ptr) = alloc();

    %{
        ids.memory_init_state_len = len(program_input["memory_init_state"])
        segments.write_arg(ids.memory_init_state, program_input["memory_init_state"])
        segments.write_arg(ids.size_mcopy_ptr, program_input["size_mcopy"])
        segments.write_arg(ids.src_offset_mcopy_ptr, program_input["src_offset_mcopy"])
        segments.write_arg(ids.dst_offset_mcopy_ptr, program_input["dst_offset_mcopy"])
    %}

    let size_mcopy = cast(size_mcopy_ptr, Uint256*);
    let src_offset_mcopy = cast(src_offset_mcopy_ptr, Uint256*);
    let dst_offset_mcopy = cast(dst_offset_mcopy_ptr, Uint256*);

    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = TestHelpers.init_memory_with_values(memory_init_state_len, memory_init_state);

    with stack, memory, state {
        Stack.push(size_mcopy);
        Stack.push(src_offset_mcopy);
        Stack.push(dst_offset_mcopy);
        let evm = MemoryOperations.exec_mcopy(evm);
    }
    return (evm, memory);
}

func test_exec_mstore{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.EVM*, model.Memory*) {
    alloc_locals;
    let (value_ptr) = alloc();
    let (offset_ptr) = alloc();

    %{
        segments.write_arg(ids.value_ptr, program_input["value"])
        segments.write_arg(ids.offset_ptr, program_input["offset"])
    %}

    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    let value = cast(value_ptr, Uint256*);
    let offset = cast(offset_ptr, Uint256*);

    with stack, memory, state {
        Stack.push(value);
        Stack.push(offset);

        let evm = MemoryOperations.exec_mstore(evm);
    }
    return (evm, memory);
}
