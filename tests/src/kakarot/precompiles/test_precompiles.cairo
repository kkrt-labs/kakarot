%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from kakarot.precompiles.precompiles import Precompiles

func test__is_precompile{range_check_ptr}() -> felt {
    alloc_locals;
    // Given
    local address;
    %{ ids.address = program_input["address"] %}

    // When
    let is_precompile = Precompiles.is_precompile(address);
    return is_precompile;
}

func test__precompiles_run{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output: felt*, reverted: felt) {
    alloc_locals;
    // Given
    local address;
    local input_len;
    let (local input) = alloc();
    %{
        ids.address = program_input["address"]
        ids.input_len = len(program_input["input"])
        segments.write_arg(ids.input, program_input["input"])
    %}

    // When
    let result = Precompiles.exec_precompile(evm_address=address, input_len=input_len, input=input);
    return (result.output, result.reverted);
}
