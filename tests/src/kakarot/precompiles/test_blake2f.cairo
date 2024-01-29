%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset

from utils.utils import Helpers
from kakarot.precompiles.blake2f import PrecompileBlake2f

func test_should_fail_when_input_is_not_213{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 212;

    let result = PrecompileBlake2f.run(0x09, input_len, input);
    memcpy(output_ptr, result.output, result.output_len);
    return ();
}

func test_should_fail_when_flag_is_not_0_or_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 213;
    memset(input, input_len - 1, 0x00);
    assert input[212] = 0x02;

    let result = PrecompileBlake2f.run(0x09, input_len, input);
    memcpy(output_ptr, result.output, result.output_len);
    return ();
}

func test_should_return_blake2f_compression{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;

    local rounds: felt;
    local h_len: felt;
    let (h: felt*) = alloc();
    local m_len: felt;
    let (m: felt*) = alloc();
    local t0: felt;
    local t1: felt;
    local f: felt;
    %{
        ids.rounds = program_input["rounds"]
        ids.h_len = len(program_input["h"])
        segments.write_arg(ids.h, program_input["h"])
        ids.m_len = len(program_input["m"])
        segments.write_arg(ids.m, program_input["m"])
        ids.t0 = program_input["t0"]
        ids.t1 = program_input["t1"]
        ids.f = program_input["f"]
    %}

    let (local input: felt*) = alloc();
    Helpers.split_word(rounds, 4, input);
    memcpy(input + 4, h, h_len);
    memcpy(input + 68, m, m_len);
    Helpers.split_word_little(t0, 8, input + 196);
    Helpers.split_word_little(t1, 8, input + 196 + 8);
    assert input[212] = f;

    let (output_len, output, gas, reverted) = PrecompileBlake2f.run(0x09, 213, input);
    memcpy(output_ptr, output, output_len);
    return ();
}
