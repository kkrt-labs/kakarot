%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from kakarot.evm import EVM
from kakarot.model import model
from tests.utils.helpers import TestHelpers


func test__jump{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> model.EVM* {
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

    return evm;
}
