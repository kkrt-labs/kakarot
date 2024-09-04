%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from kakarot.precompiles.kakarot_precompiles import KakarotPrecompiles

func test__cairo_message{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output_len: felt, output: felt*, reverted: felt, gas_used: felt) {
    alloc_locals;
    // Given
    local input_len;
    local caller_address;
    let (local input) = alloc();
    %{
        ids.input_len = len(program_input["input"])
        segments.write_arg(ids.input, program_input["input"])
        ids.caller_address = program_input.get("caller_address", 0)
    %}

    // When
    let result = KakarotPrecompiles.cairo_message(
        input_len=input_len, input=input, caller_address=caller_address
    );

    return (result.output_len, result.output, result.reverted, result.gas_used);
}
