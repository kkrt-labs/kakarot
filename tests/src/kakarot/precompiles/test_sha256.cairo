%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy

from kakarot.precompiles.sha256 import PrecompileSHA256
from utils.utils import Helpers

func test__sha256{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;
    local data_len: felt;
    let (data: felt*) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    let (hash_len, hash, gas_used, reverted) = PrecompileSHA256.run(
        PrecompileSHA256.PRECOMPILE_ADDRESS, data_len, data
    );
    let (minimum_word_size) = Helpers.minimum_word_count(data_len);
    assert gas_used = 12 * minimum_word_size + PrecompileSHA256.GAS_COST_SHA256;

    memcpy(output_ptr, hash, hash_len);
    return ();
}
