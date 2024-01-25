%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy

from kakarot.precompiles.precompiles import Precompiles

func test__is_precompile{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    // Given
    local address;
    %{ ids.address = program_input["address"] %}

    // When
    let is_precompile = Precompiles.is_precompile(address);
    assert [output_ptr] = is_precompile;
    return ();
}

func test__precompiles_run{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;
    // Given
    local address;
    %{ ids.address = program_input["address"] %}

    // When
    let result = Precompiles.exec_precompile(
        evm_address=address, input_len=0, input=cast(0, felt*)
    );

    memcpy(output_ptr, result.output, result.output_len);
    assert [output_ptr + result.output_len] = result.reverted;
    return ();
}
