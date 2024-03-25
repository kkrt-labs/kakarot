%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from kakarot.accounts.library import GenericAccount

func test__initialize__should_store_given_evm_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    local evm_address: felt;
    local kakarot_address: felt;
    %{
        ids.evm_address = program_input["evm_address"]
        ids.kakarot_address = program_input["kakarot_address"]
    %}

    // When
    GenericAccount.initialize(kakarot_address, evm_address);

    return ();
}

func test__get_evm_address__should_return_stored_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;

    let (evm_address) = GenericAccount.get_evm_address();

    assert [output_ptr] = evm_address;

    return ();
}
