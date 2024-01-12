%builtins range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import assert_nn

from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory

func test__init__should_return_an_empty_memory() {
    // When
    let memory = Memory.init();

    // Then
    assert memory.words_len = 0;
    return ();
}

func test__store__should_add_an_element_to_the_memory{range_check_ptr}() {
    alloc_locals;
    // Given
    let memory = Memory.init();
    let value = Uint256(1, 0);

    // When
    with memory {
        Memory.store(value, 0);
    }

    // Then
    assert memory.words_len = 1;
    return ();
}

func test__load__should_load_an_element_from_the_memory_with_offset{range_check_ptr}() {
    alloc_locals;
    // Given
    local offset: felt;
    local low: felt;
    local high: felt;
    %{
        ids.offset = program_input["offset"];
        ids.low = program_input["low"];
        ids.high = program_input["high"];
    %}

    let memory = Memory.init();
    let first_value = Uint256(low=2, high=1);
    let second_value = Uint256(low=4, high=3);

    // When
    with memory {
        Memory.store(first_value, 0);
        Memory.store(second_value, 32);
        let result = Memory.load(offset);
    }

    // Then
    assert_uint256_eq(result, Uint256(low, high));

    return ();
}

func test__load__should_expand_memory_and_return_element{range_check_ptr}() {
    // Given
    alloc_locals;
    let memory = Memory.init();
    let value = Uint256(1, 0);

    // When
    with memory {
        Memory.store(value, 0);
        let value = Memory.load(0);
        // Then
        assert value = Uint256(1, 0);
        assert memory.words_len = 1;

        let value = Memory.load(32);
    }
    assert value = Uint256(0, 0);
    assert memory.words_len = 2;
    return ();
}
