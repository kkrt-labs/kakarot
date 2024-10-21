%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from kakarot.precompiles.kakarot_precompiles import Internals

func test__parse_cairo_call{range_check_ptr}() -> (
    is_err: felt,
    to_addr: felt,
    selector: felt,
    calldata_len: felt,
    calldata: felt*,
    next_call_offset: felt,
) {
    alloc_locals;
    // Given
    local evm_encoded_call_len;
    let (local evm_encoded_call) = alloc();
    %{
        ids.evm_encoded_call_len = len(program_input["evm_encoded_call"])
        segments.write_arg(ids.evm_encoded_call, program_input["evm_encoded_call"])
    %}

    // When
    let (
        is_err, to_addr, selector, calldata_len, calldata, next_call_offset
    ) = Internals.parse_cairo_call(evm_encoded_call_len, evm_encoded_call);
    return (is_err, to_addr, selector, calldata_len, calldata, next_call_offset);
}
