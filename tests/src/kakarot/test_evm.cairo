%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from kakarot.evm import EVM, Internals
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

func test__is_jumpdest_valid{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> felt {
    alloc_locals;

    tempvar cached_jumpdests_len;
    let (cached_jumpdests) = alloc();
    local index;

    %{
        ids.cached_jumpdests_len = len(program_input["cached_jumpdests"])
        segments.write_arg(ids.cached_jumpdests, program_input["cached_jumpdests"])
        ids.index = program_input["index"]
    %}

    let (valid_jumpdests_start, valid_jumpdests) = TestHelpers.init_jumpdests_with_values(
        cached_jumpdests_len, cached_jumpdests
    );

    with valid_jumpdests {
        let result = Internals.is_jumpdest_valid(0, 0, index);
    }

    return result;
}
