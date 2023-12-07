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
    let memory = Memory.init();

    // Then
    assert memory.words_len = 0;
    return ();
}

@external
func test__store__should_add_an_element_to_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    // Given
    let memory = Memory.init();

    // When
    let value = Uint256(1, 0);
    let memory = Memory.store(memory, value, 0);

    // Then
    assert memory.words_len = 1;
    return ();
}

@external
func test__load__should_load_an_element_from_the_memory_with_offset{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(offset: felt, low: felt, high: felt) {
    alloc_locals;
    // Given
    let memory = Memory.init();
    let first_value = Uint256(low=2, high=1);
    let second_value = Uint256(low=4, high=3);
    let memory = Memory.store(memory, first_value, 0);
    let memory = Memory.store(memory, second_value, 32);

    // When
    let (memory, result) = Memory.load(memory, offset);

    // Then
    assert_uint256_eq(result, Uint256(low, high));

    return ();
}

@external
func test__load__should_expand_memory_and_return_element{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);

    // When
    let memory = Memory.store(memory, value, 0);

    // Then
    let (memory, value) = Memory.load(memory, 0);
    assert value = Uint256(1, 0);
    assert memory.words_len = 1;

    let (memory, value) = Memory.load(memory, 32);
    assert value = Uint256(0, 0);
    assert memory.words_len = 2;
    return ();
}

@external
func test__cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    max_offset: felt
) -> (cost: felt) {
    let cost = Internals.cost(max_offset);
    return (cost=cost);
}
