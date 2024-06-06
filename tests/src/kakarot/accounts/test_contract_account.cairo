%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256

from kakarot.accounts.library import Internals as AccountInternals
from kakarot.accounts.account_contract import (
    initialize,
    get_evm_address,
    write_bytecode,
    bytecode as read_bytecode,
    write_jumpdests,
    is_valid_jumpdest,
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

func test__validate{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}() {
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
    AccountInternals.validate(address, nonce, chain_id, r, s, v, tx_data_len, tx_data);

    return ();
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
