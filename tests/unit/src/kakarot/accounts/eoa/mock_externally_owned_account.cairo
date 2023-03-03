// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

from kakarot.accounts.eoa.library import ExternallyOwnedAccount
from kakarot.accounts.library import Accounts
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

// @notice This function is used to read the nonce from storage
// @return nonce: The current nonce of the contract account
@view
func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    return Accounts.get_nonce();
}

// @notice This function increases the EOAs nonce by 1
// @return nonce: The new nonce of the EOA
@external
func increment_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    nonce: felt
) {
    Accounts.increment_nonce();
    return Accounts.get_nonce();
}
