// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

from kakarot.accounts.eoa.library import ExternallyOwnedAccount
from openzeppelin.access.ownable.library import Ownable

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _kakarot_address: felt
) {
    Ownable.initializer(_kakarot_address);
    return ();
}

@external
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    call_array_len: felt,
    call_array: ExternallyOwnedAccount.CallArray*,
    calldata_len: felt,
    calldata: felt*,
) -> (response_len: felt, response: felt*) {
    alloc_locals;
    let (local response: felt*) = alloc();
    let (response_len) = ExternallyOwnedAccount.execute(
        call_array_len, call_array, calldata_len, calldata, response
    );
    return (response_len, response);
}
