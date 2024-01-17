%builtins range_check

from kakarot.gas import Gas
from starkware.cairo.common.uint256 import Uint256

func test__memory_cost{range_check_ptr}() {
    tempvar words_len: felt;
    %{ ids.words_len = program_input["words_len"]; %}
    let cost = Gas.memory_cost(words_len);

    %{ segments.write_arg(output, [ids.cost]); %}
    return ();
}

func test__memory_expansion_cost{range_check_ptr}() {
    tempvar words_len: felt;
    tempvar max_offset: felt;
    %{
        ids.words_len = program_input["words_len"];
        ids.max_offset = program_input["max_offset"];
    %}
    let cost = Gas.memory_expansion_cost(words_len, max_offset);

    %{ segments.write_arg(output, [ids.cost]); %}
    return ();
}

func test__max_memory_expansion_cost{range_check_ptr}() {
    tempvar words_len: felt;
    tempvar offset_1: Uint256;
    tempvar size_1: Uint256;
    tempvar offset_2: Uint256;
    tempvar size_2: Uint256;
    %{
        ids.words_len = program_input["words_len"];
        ids.offset_1.low = program_input["offset_1"];
        ids.offset_1.high = 0;
        ids.size_1.low = program_input["size_1"];
        ids.size_1.high = 0;
        ids.offset_2.low = program_input["offset_2"];
        ids.offset_2.high = 0;
        ids.size_2.low = program_input["size_2"];
        ids.size_2.high = 0;
    %}
    let cost = Gas.max_memory_expansion_cost(words_len, offset_1, size_1, offset_2, size_2);

    %{ segments.write_arg(output, [ids.cost]); %}
    return ();
}

func test__compute_message_call_gas{range_check_ptr}() {
    tempvar gas_param: Uint256;
    tempvar gas_left: felt;

    %{
        ids.gas_param.low = program_input["gas_param"];
        ids.gas_param.high = 0;
        ids.gas_left = program_input["gas_left"];
    %}
    let gas = Gas.compute_message_call_gas(gas_param, gas_left);

    %{ segments.write_arg(output, [ids.gas]); %}
    return ();
}
