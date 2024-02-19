%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from backend.starknet import Starknet
from kakarot.model import model

func test__get_env{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> model.Environment* {
    alloc_locals;
    tempvar origin;
    tempvar gas_price;
    %{
        ids.origin = program_input["origin"]
        ids.gas_price = program_input["gas_price"]
    %}
    let env = Starknet.get_env(origin, gas_price);
    return env;
}
