%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from kakarot.library import Kakarot
from kakarot.model import model

func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.EVM*, model.State*, felt) {
    // Given

    tempvar origin;
    tempvar to: model.Option;
    tempvar gas_limit;
    tempvar gas_price;
    let (value_ptr) = alloc();
    tempvar data_len: felt;
    let (data) = alloc();
    tempvar access_list_len: felt;
    let (access_list) = alloc();

    %{
        from tests.utils.uint256 import int_to_uint256


        ids.origin = program_input.get("origin", 0)
        ids.to.is_some = int(bool(program_input.get("to") is not None))
        ids.to.value = program_input.get("to", 0)
        ids.gas_limit = program_input.get("gas_limit", int(2**63 - 1))
        ids.gas_price = program_input.get("gas_price", 0)
        segments.write_arg(ids.value_ptr, int_to_uint256(program_input.get("value", 0)))
        data = bytes.fromhex(program_input.get("data", "").replace("0x", ""))
        ids.data_len = len(data)
        segments.write_arg(ids.data, list(data))
        ids.access_list_len = 0
    %}

    let (evm, state, gas_used) = Kakarot.eth_call(
        origin=origin,
        to=to,
        gas_limit=gas_limit,
        gas_price=gas_price,
        value=cast(value_ptr, Uint256*),
        data_len=data_len,
        data=data,
        access_list_len=access_list_len,
        access_list=access_list,
    );

    return (evm, state, gas_used);
}
