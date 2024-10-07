%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy

from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160

func test__ripemd160{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;
    tempvar msg_len: felt;
    let (msg: felt*) = alloc();
    %{
        ids.msg_len = len(program_input["msg"])
        segments.write_arg(ids.msg, program_input["msg"])
    %}

    let (hash_len, hash, gas, reverted) = PrecompileRIPEMD160.run(
        PrecompileRIPEMD160.PRECOMPILE_ADDRESS, msg_len, msg
    );

    memcpy(output_ptr, hash, hash_len);
    return ();
}
