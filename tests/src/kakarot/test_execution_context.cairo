%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from kakarot.evm import EVM
from tests.utils.helpers import TestHelpers

func test__jump{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    output_ptr: felt*
) {
    alloc_locals;
    local bytecode_len: felt;
    let (bytecode) = alloc();
    local jumpdest: felt;
    %{
        ids.bytecode_len = len(program_input["bytecode"]);
        segments.write_arg(ids.bytecode, program_input["bytecode"]);
        ids.jumpdest = program_input["jumpdest"];
    %}
    let evm = TestHelpers.init_evm_with_bytecode(bytecode_len, bytecode);
    let evm = EVM.jump(evm, jumpdest);

    assert [output_ptr] = evm.program_counter;
    assert [output_ptr + 1] = evm.return_data_len;
    memcpy(output_ptr + 2, evm.return_data, evm.return_data_len);

    return ();
}
