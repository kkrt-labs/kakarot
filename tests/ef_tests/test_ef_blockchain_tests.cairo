%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from kakarot.library import Kakarot
from kakarot.model import model

func test_should_return_correct_state{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.EVM*, model.State*, felt) {
    // Given

    tempvar data_len: felt;
    let (data) = alloc();
    tempvar access_list_len: felt;
    let (access_list) = alloc();
    tempvar gas_limit: felt;
    tempvar gas_price: felt;
    tempvar nonce: felt;
    tempvar sender: felt;
    tempvar to: model.Option;
    let (value_ptr) = alloc();

    %{
        from tests.utils.uint256 import int_to_uint256


        data = bytes.fromhex(program_input["data"].replace("0x", ""))
        ids.data_len = len(data)
        segments.write_arg(ids.data, list(data))
        # TODO: access_list
        ids.access_list_len = 0
        ids.gas_limit = int(program_input["gasLimit"], 16)
        ids.gas_price = int(program_input["gasPrice"], 16)
        ids.nonce = int(program_input["nonce"], 16)
        ids.sender = int(program_input["sender"], 16)
        ids.to.is_some = bool(program_input["to"] != "")
        if ids.to.is_some:
            ids.to.value = int(program_input["to"], 16)
        else:
            ids.to.value = 0
        segments.write_arg(ids.value_ptr, int_to_uint256(int(program_input["value"], 16)))
    %}

    let (evm, state, gas_used) = Kakarot.eth_call(
        sender,
        to,
        gas_limit,
        gas_price,
        cast(value_ptr, Uint256*),
        data_len,
        data,
        access_list_len,
        access_list,
    );

    return (evm, state, gas_used);
}
