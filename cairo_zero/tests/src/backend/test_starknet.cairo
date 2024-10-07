%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.dict_access import DictAccess

from backend.starknet import Starknet, Internals as StarknetInternals
from kakarot.model import model
from kakarot.library import Kakarot

func test__get_env{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> model.Environment* {
    alloc_locals;
    tempvar origin;
    tempvar gas_price;
    %{
        ids.origin = program_input["origin"]
        ids.gas_price = program_input["gas_price"]
    %}
    let (chain_id) = Kakarot.eth_chain_id();
    let env = Starknet.get_env(origin, gas_price, chain_id);
    return env;
}

func test__save_valid_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local jumpdests_start: felt*) = alloc();
    local jumpdests_end: felt*;
    local contract_address: felt;
    %{
        # jumpdests must be formatted as {index_1: True, index_3: False, index_5: True, ...}
        serialized_input = [i for key, value in program_input["jumpdests"].items() for i in (key, 0, int(value))]
        segments.write_arg(ids.jumpdests_start, serialized_input)
        ids.jumpdests_end = ids.jumpdests_start + len(serialized_input)
        ids.contract_address = program_input["contract_address"]
    %}

    StarknetInternals._save_valid_jumpdests(
        contract_address, cast(jumpdests_start, DictAccess*), cast(jumpdests_end, DictAccess*)
    );
    return ();
}
