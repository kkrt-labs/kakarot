%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.memset import memset
from starkware.cairo.common.memcpy import memcpy

from kakarot.precompiles.ec_recover import PrecompileEcRecover
from utils.utils import Helpers

func test__ec_recover{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output: felt*) {
    alloc_locals;
    let (local input) = alloc();
    tempvar input_len: felt;
    %{
        ids.input_len = len(program_input["input"]);
        segments.write_arg(ids.input, program_input["input"])
    %}
    let (output_len: felt, output: felt*, gas_used: felt, reverted: felt) = PrecompileEcRecover.run(
        PrecompileEcRecover.PRECOMPILE_ADDRESS, input_len, input
    );
    return (output=output);
}
