%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

from kakarot.accounts.library import Internals as AccountInternals, AccountContract
from kakarot.accounts.account_contract import (
    initialize,
    get_evm_address,
    write_bytecode,
    bytecode as read_bytecode,
    write_jumpdests,
    is_valid_jumpdest,
    set_nonce,
    set_implementation,
    set_authorized_pre_eip155_tx,
    execute_starknet_call,
)

func test__initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    local kakarot_address: felt;
    local evm_address: felt;
    local implementation_class: felt;
    %{
        ids.kakarot_address = program_input["kakarot_address"]
        ids.evm_address = program_input["evm_address"]
        ids.implementation_class = program_input["implementation_class"]
    %}

    // When
    initialize(kakarot_address, evm_address, implementation_class);

    return ();
}

func test__get_evm_address__should_return_stored_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> felt {
    let (evm_address) = get_evm_address();

    return evm_address;
}

func test__write_bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    local bytecode_len: felt;
    let (bytecode: felt*) = alloc();
    %{
        ids.bytecode_len = len(program_input["bytecode"])
        segments.write_arg(ids.bytecode, program_input["bytecode"])
    %}

    write_bytecode(bytecode_len, bytecode);

    return ();
}

func test__bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (bytecode_len: felt, bytecode: felt*) {
    alloc_locals;
    let (bytecode_len, bytecode) = read_bytecode();
    return (bytecode_len, bytecode);
}

func test__set_nonce{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    local new_nonce: felt;
    %{ ids.new_nonce = program_input["new_nonce"] %}
    set_nonce(new_nonce);
    return ();
}

func test__set_implementation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    local new_implementation: felt;
    %{ ids.new_implementation = program_input["new_implementation"] %}
    set_implementation(new_implementation);
    return ();
}

func test__set_authorized_pre_eip155_tx{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    local msg_hash: Uint256;
    %{
        ids.msg_hash.low = program_input["msg_hash"][0]
        ids.msg_hash.high = program_input["msg_hash"][1]
    %}

    set_authorized_pre_eip155_tx(msg_hash);
    return ();
}
func test__execute_starknet_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (felt*, felt) {
    // Given
    tempvar called_address: felt;
    tempvar function_selector: felt;
    tempvar calldata_len: felt;
    let (calldata) = alloc();
    %{
        ids.called_address = program_input["called_address"]
        ids.function_selector = program_input["function_selector"]
        ids.calldata_len = len(program_input["calldata"])
        segments.write_arg(ids.calldata, program_input["calldata"])
    %}

    // When
    let (retdata_len, retdata, success) = execute_starknet_call(
        called_address, function_selector, calldata_len, calldata
    );

    return (retdata, success);
}

func test__execute_from_outside{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}() -> felt* {
    // Given
    tempvar tx_data_len: felt;
    let (tx_data) = alloc();
    tempvar signature_len: felt;
    let (signature) = alloc();
    tempvar chain_id: felt;

    %{
        ids.tx_data_len = len(program_input["tx_data"])
        segments.write_arg(ids.tx_data, program_input["tx_data"])
        ids.signature_len = len(program_input["signature"])
        segments.write_arg(ids.signature, program_input["signature"])
        ids.chain_id = program_input["chain_id"]
    %}

    // When
    let (return_data_len, return_data) = AccountContract.execute_from_outside(
        tx_data_len, tx_data, signature_len, signature, chain_id
    );

    return return_data;
}

func test__write_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // Given
    tempvar jumpdests_len: felt;
    let (jumpdests) = alloc();
    %{
        ids.jumpdests_len = len(program_input["jumpdests"])
        segments.write_arg(ids.jumpdests, program_input["jumpdests"])
    %}

    // When
    write_jumpdests(jumpdests_len, jumpdests);

    return ();
}

func test__is_valid_jumpdest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> felt {
    tempvar index: felt;
    %{ ids.index = program_input["index"] %}

    let (is_valid) = is_valid_jumpdest(index);

    return is_valid;
}
