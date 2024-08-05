%builtins range_check
from starkware.cairo.common.alloc import alloc

from kakarot.gas import Gas
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.lang.compiler.lib.registers import get_fp_and_pc

func test__memory_cost{range_check_ptr}() -> felt {
    tempvar words_len: felt;
    %{ ids.words_len = program_input["words_len"]; %}
    let cost = Gas.memory_cost(words_len);

    return cost;
}

func test__memory_expansion_cost{range_check_ptr}() -> felt {
    tempvar words_len: felt;
    tempvar max_offset: felt;
    %{
        ids.words_len = program_input["words_len"];
        ids.max_offset = program_input["max_offset"];
    %}
    let memory_expansion = Gas.calculate_gas_extend_memory(words_len, max_offset);

    return memory_expansion.cost;
}

func test__max_memory_expansion_cost{range_check_ptr}() -> felt {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    local words_len: felt;
    local offset_1: Uint256;
    local size_1: Uint256;
    local offset_2: Uint256;
    local size_2: Uint256;
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
    let memory_expansion = Gas.max_memory_expansion_cost(
        words_len, &offset_1, &size_1, &offset_2, &size_2
    );

    return memory_expansion.cost;
}

func test__memory_expansion_cost_saturated{range_check_ptr}() -> felt {
    alloc_locals;
    local words_len: felt;
    let (offset) = alloc();
    let (size) = alloc();
    %{
        from tests.utils.uint256 import int_to_uint256
        ids.words_len = program_input["words_len"]
        segments.write_arg(ids.offset, int_to_uint256(program_input["offset"]))
        segments.write_arg(ids.size, int_to_uint256(program_input["size"]))
    %}

    let memory_expansion = Gas.memory_expansion_cost_saturated(
        words_len, [cast(offset, Uint256*)], [cast(size, Uint256*)]
    );
    return memory_expansion.cost;
}

func test__compute_message_call_gas{range_check_ptr}() -> felt {
    tempvar gas_param: Uint256;
    tempvar gas_left: felt;
    %{
        ids.gas_param.low = program_input["gas_param"];
        ids.gas_param.high = 0;
        ids.gas_left = program_input["gas_left"];
    %}
    let gas = Gas.compute_message_call_gas(gas_param, gas_left);

    return gas;
}
