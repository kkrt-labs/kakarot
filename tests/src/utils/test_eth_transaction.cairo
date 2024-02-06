%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from kakarot.model import model
from utils.eth_transaction import EthTransaction
from utils.rlp import RLP

func test__decode{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}() -> model.EthTransaction* {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    let tx = EthTransaction.decode(data_len, data);
    return tx;
}

func test__validate{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}() {
    // Given
    tempvar address: felt;
    tempvar nonce: felt;
    tempvar chain_id: felt;
    tempvar r: Uint256;
    tempvar s: Uint256;
    tempvar v: felt;
    tempvar tx_data_len: felt;
    let (tx_data) = alloc();
    %{
        ids.address = program_input["address"]
        ids.nonce = program_input["nonce"]
        ids.chain_id = program_input["chain_id"]
        ids.r.low = program_input["r"][0]
        ids.r.high = program_input["r"][1]
        ids.s.low = program_input["s"][0]
        ids.s.high = program_input["s"][1]
        ids.v = program_input["v"]
        ids.tx_data_len = len(program_input["tx_data"])
        segments.write_arg(ids.tx_data, program_input["tx_data"])
    %}

    // When
    EthTransaction.validate(address, nonce, chain_id, r, s, v, tx_data_len, tx_data);

    return ();
}

func test__parse_access_list{range_check_ptr}(output_ptr: felt*) {
    alloc_locals;
    // Given
    tempvar data_len: felt;
    let (data) = alloc();
    %{
        ids.data_len = len(program_input["data"])
        segments.write_arg(ids.data, program_input["data"])
    %}

    // Decode the RLP-encoded access list to get the data in the cairo format
    let (items: RLP.Item*) = alloc();
    RLP.decode(items, data_len, data);

    // first level RLP decoding is a list of items. In our case the only item we decoded was the access list.
    // the access list is a list of tuples (address, list(keys)), hence first level RLP decoding
    // is a single item of type list.
    let (local access_list: felt*) = alloc();
    // When
    let access_list_len = EthTransaction.parse_access_list(
        access_list, items.data_len, cast(items.data, RLP.Item*)
    );

    memcpy(output_ptr, access_list, access_list_len);
    return ();
}

func test__get_tx_type{range_check_ptr}() -> felt {
    alloc_locals;
    // Given
    let (data) = alloc();
    %{ segments.write_arg(ids.data, program_input["data"]) %}

    // When
    let tx_type = EthTransaction.get_tx_type(data);

    return tx_type;
}
