// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory

@view
func __setup__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ();
}

@external
func test__init__should_return_an_empty_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // When
    let result: model.Memory* = Memory.init();

    // Then
    assert result.raw_len = 0;
    return ();
}

@external
func test__len__should_return_the_length_of_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let memory: model.Memory* = Memory.init();

    // When
    let result: felt = Memory.len(memory);

    // Then
    assert result = 0;
    return ();
}

@external
func test__store__should_add_an_element_to_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let memory: model.Memory* = Memory.init();

    // When
    let result: model.Memory* = Memory.store(memory, Uint256(1, 0), 0);

    // Then
    let len: felt = Memory.len(result);
    assert len = 1;
    return ();
}

@external
func test__load__should_load_an_element_from_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(memory, Uint256(1, 0), 0);

    // When
    let result = Memory.load(memory, 0);

    // Then
    assert result = Uint256(1, 0);
    return ();
}

@external
func test__load__should_fail__when_out_of_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(memory, Uint256(1, 0), 0);

    // When & Then
    let result = Memory.load(memory, 2);
    return ();
}

@external
func test__dump__should_print_the_memory{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(1, 0), offset=0);
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(2, 0), offset=1);
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(3, 0), offset=2);
    let len = Memory.len(memory);
    assert len = 3;

    // When & Then
    Memory.dump(memory);
    return ();
}
