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
}() -> (output_len: felt, output: felt*) {
    alloc_locals;

    let (local input: felt*) = alloc();
    %{ segments.write_arg(ids.input, program_input["input"]) %}

    let (output_len, output, gas, reverted) = PrecompileBlake2f.run(0x09, 213, input);
    return (output_len, output);
}
