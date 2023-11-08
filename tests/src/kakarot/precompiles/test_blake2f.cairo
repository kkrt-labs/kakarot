// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.blake2f import PrecompileBlake2f
from tests.utils.helpers import TestHelpers

@external
func test_should_fail_when_input_is_not_213{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output_len: felt, output: felt*) {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 212;

    let result = PrecompileBlake2f.run(0x09, input_len, input);
    return (result.output_len, result.output);
}

@external
func test_should_fail_when_flag_is_not_0_or_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output_len: felt, output: felt*) {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 213;
    TestHelpers.array_fill(input, input_len - 1, 0x00);
    assert input[212] = 0x02;

    let result = PrecompileBlake2f.run(0x09, input_len, input);
    return (result.output_len, result.output);
}

@external
func test_should_return_blake2f_compression{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(rounds: felt, h_len: felt, h: felt*, m_len: felt, m: felt*, t0: felt, t1: felt, f: felt) -> (
    output_len: felt, output: felt*
) {
    alloc_locals;
    let (local input: felt*) = alloc();
    Helpers.split_word(rounds, 4, input);
    Helpers.fill_array(h_len, h, input + 4);
    Helpers.fill_array(m_len, m, input + 68);
    Helpers.split_word_little(t0, 8, input + 196);
    Helpers.split_word_little(t1, 8, input + 196 + 8);
    assert input[212] = f;

    let (output_len, output, gas, reverted) = PrecompileBlake2f.run(0x09, 213, input);

    return (output_len=output_len, output=output);
}
