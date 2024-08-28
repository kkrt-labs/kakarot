%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from kakarot.library import Kakarot
from kakarot.kakarot import (
    eth_send_raw_unsigned_tx,
    register_account,
    set_native_token,
    set_base_fee,
    set_coinbase,
    set_prev_randao,
    set_block_gas_limit,
    set_account_contract_class_hash,
    set_uninitialized_account_class_hash,
    set_authorized_cairo_precompile_caller,
    set_cairo1_helpers_class_hash,
    transfer_ownership,
)
from kakarot.model import model
from kakarot.account import Account

func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.EVM*, model.State*, felt, felt) {
    tempvar origin;
    tempvar to: model.Option;
    tempvar gas_limit;
    tempvar gas_price;
    tempvar nonce;
    let (value_ptr) = alloc();
    tempvar data_len: felt;
    let (data) = alloc();
    tempvar access_list_len: felt;
    let (access_list) = alloc();

    %{
        from kakarot_scripts.utils.uint256 import int_to_uint256

        ids.origin = program_input.get("origin", 0)
        ids.to.is_some = int(bool(program_input.get("to") is not None))
        ids.to.value = program_input.get("to") or 0
        ids.gas_limit = program_input.get("gas_limit", int(2**63 - 1))
        ids.gas_price = program_input.get("gas_price", 0)
        ids.nonce = program_input.get("nonce", 0)
        segments.write_arg(ids.value_ptr, int_to_uint256(program_input.get("value", 0)))
        data = bytes.fromhex(program_input.get("data", "").replace("0x", ""))
        ids.data_len = len(data)
        segments.write_arg(ids.data, list(data))
        ids.access_list_len = 0
    %}

    let (evm, state, gas_used, required_gas) = Kakarot.eth_call(
        nonce=nonce,
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

    return (evm, state, gas_used, required_gas);
}

func test__eth_send_raw_unsigned_tx{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (felt, felt*, felt, felt) {
    tempvar tx_data_len: felt;
    let (tx_data) = alloc();

    %{
        segments.write_arg(ids.tx_data, program_input["tx_data"])
        ids.tx_data_len = len(program_input["tx_data"])
    %}

    let (return_data_len, return_data, success, gas_used) = eth_send_raw_unsigned_tx(
        tx_data_len=tx_data_len, tx_data=tx_data
    );

    return (return_data_len, return_data, success, gas_used);
}

func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> felt {
    tempvar evm_address;

    %{ ids.evm_address = program_input["evm_address"] %}

    let starknet_address = Account.compute_starknet_address(evm_address=evm_address);

    return starknet_address;
}

func test__register_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar evm_address;

    %{ ids.evm_address = program_input["evm_address"] %}

    register_account(evm_address=evm_address);

    return ();
}

func test__transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar new_owner;

    %{ ids.new_owner = program_input["new_owner"] %}

    transfer_ownership(new_owner);

    return ();
}

func test__set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar address;

    %{ ids.address = program_input["address"] %}

    set_native_token(address);
    return ();
}

func test__set_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar coinbase;

    %{ ids.coinbase = program_input["coinbase"] %}

    set_coinbase(coinbase);
    return ();
}

func test__set_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar base_fee;

    %{ ids.base_fee = program_input["base_fee"] %}

    set_base_fee(base_fee);
    return ();
}

func test__set_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar prev_randao;

    %{ ids.prev_randao = program_input["prev_randao"] %}

    set_prev_randao(Uint256(prev_randao, 0));
    return ();
}

func test__set_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar block_gas_limit;

    %{ ids.block_gas_limit = program_input["block_gas_limit"] %}

    set_block_gas_limit(block_gas_limit);
    return ();
}

func test__set_account_contract_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    tempvar value;

    %{ ids.value = program_input["class_hash"] %}

    set_account_contract_class_hash(value);
    return ();
}

func test__set_uninitialized_account_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    tempvar value;

    %{ ids.value = program_input["class_hash"] %}

    set_uninitialized_account_class_hash(value);
    return ();
}

func test__set_authorized_cairo_precompile_caller{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    tempvar caller_address;
    tempvar authorized;

    %{
        ids.caller_address = program_input["caller_address"]
        ids.authorized = program_input["authorized"]
    %}

    set_authorized_cairo_precompile_caller(caller_address, authorized);

    return ();
}

func test__set_cairo1_helpers_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    tempvar value;

    %{ ids.value = program_input["class_hash"] %}

    set_cairo1_helpers_class_hash(value);
    return ();
}

func test__eth_chain_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> felt {
    let (chain_id) = Kakarot.eth_chain_id();
    return chain_id;
}
