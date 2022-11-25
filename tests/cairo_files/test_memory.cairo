// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_nn

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory

@external
func test__init__should_return_an_empty_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let result: model.Memory* = Memory.init();

    // Then
    assert result.bytes_len = 0;
    return ();
}

@external
func test__len__should_return_the_length_of_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let memory: model.Memory* = Memory.init();

    // When
    let result: felt = memory.bytes_len;

    // Then
    assert result = 0;
    return ();
}

@external
func test__store__should_add_an_element_to_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    let memory: model.Memory* = Memory.init();

    // When
    let value = Uint256(1, 0);
    let (bytes_array_len, bytes_array) = Helpers.uint256_to_bytes_array(value);
    let result: model.Memory* = Memory.store_n(
        self=memory, element_len=bytes_array_len, element=bytes_array, offset=0
    );

    // Then
    let len: felt = result.bytes_len;
    assert len = 32;
    return ();
}

@external
func test__load__should_load_an_element_from_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    let memory: model.Memory* = Memory.init();
    // In the memory, the following values are stored in the order 1, 2, 3, 4 (Big Endian)
    let first_value = Uint256(low=2, high=1);
    let second_value = Uint256(low=4, high=3);
    let (first_bytes_array_len, first_bytes_array) = Helpers.uint256_to_bytes_array(first_value);
    let (second_bytes_array_len, second_bytes_array) = Helpers.uint256_to_bytes_array(second_value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=first_bytes_array_len, element=first_bytes_array, offset=0
    );
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=second_bytes_array_len, element=second_bytes_array, offset=32
    );

    // When
    let (memory, result) = Memory.load(memory, 0);

    // Then
    assert_uint256_eq(result, Uint256(2, 1));

    // When
    let (memory, result) = Memory.load(memory, 32);

    // Then
    assert_uint256_eq(result, Uint256(4, 3));

    // When
    let (memory, result) = Memory.load(memory, 16);

    // Then
    assert_uint256_eq(result, Uint256(3, 2));

    return ();
}

@external
func test__load__should_load_an_element_from_the_memory_with_offset{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(offset: felt, low: felt, high: felt) {
    alloc_locals;
    // Given
    let memory: model.Memory* = Memory.init();
    // In the memory, the following values are stored in the order 1, 2, 3, 4 (Big Endian)
    let first_value = Uint256(low=2, high=1);
    let second_value = Uint256(low=4, high=3);
    let (first_bytes_array_len, first_bytes_array) = Helpers.uint256_to_bytes_array(first_value);
    let (second_bytes_array_len, second_bytes_array) = Helpers.uint256_to_bytes_array(second_value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=first_bytes_array_len, element=first_bytes_array, offset=0
    );
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=second_bytes_array_len, element=second_bytes_array, offset=32
    );

    // When
    let (memory, result) = Memory.load(memory, offset);

    // Then
    assert_uint256_eq(result, Uint256(low, high));

    return ();
}

@external
func test__expand__should_return_the_same_memory_and_no_cost{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);
    let (bytes_array_len, bytes_array) = Helpers.uint256_to_bytes_array(value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=bytes_array_len, element=bytes_array, offset=0
    );

    // When
    let (memory, cost) = Memory.expand(self=memory, length=0);

    // Then
    assert cost = 0;
    assert memory.bytes_len = 32;
    let (memory, value) = Memory.load(self=memory, offset=0);
    assert value = Uint256(1, 0);

    return ();
}

@external
func test__expand__should_return_expanded_memory_and_cost{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);
    let (bytes_array_len, bytes_array) = Helpers.uint256_to_bytes_array(value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=bytes_array_len, element=bytes_array, offset=0
    );

    // When
    let (memory, cost) = Memory.expand(self=memory, length=1);

    // Then
    assert_nn(cost);
    assert memory.bytes_len = 33;
    let (memory, value) = Memory.load(self=memory, offset=0);
    assert value = Uint256(1, 0);

    return ();
}

@external
func test__ensure_length__should_return_the_same_memory_and_no_cost{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);
    let (bytes_array_len, bytes_array) = Helpers.uint256_to_bytes_array(value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=bytes_array_len, element=bytes_array, offset=0
    );

    // When
    let (memory, cost) = Memory.ensure_length(self=memory, length=1);

    // Then
    assert cost = 0;
    assert memory.bytes_len = 32;
    let (memory, value) = Memory.load(self=memory, offset=0);
    assert value = Uint256(1, 0);

    return ();
}

@external
func test__ensure_length__should_return_expanded_memory_and_cost{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);
    let (bytes_array_len, bytes_array) = Helpers.uint256_to_bytes_array(value);
    let memory: model.Memory* = Memory.store_n(
        self=memory, element_len=bytes_array_len, element=bytes_array, offset=0
    );

    // When
    let (memory, cost) = Memory.ensure_length(self=memory, length=33);

    // Then
    assert_nn(cost);
    assert memory.bytes_len = 33;
    let (memory, value) = Memory.load(self=memory, offset=0);
    assert value = Uint256(1, 0);

    return ();
}
