// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.token.erc20.IERC20 import IERC20
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_not

from kakarot.accounts.eoa.library import kakarot_address, ExternallyOwnedAccount

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _kakarot_address: felt, native_token_address: felt
) {
    kakarot_address.write(_kakarot_address);
    let (infinite) = uint256_not(Uint256(0, 0));
    IERC20.approve(native_token_address, _kakarot_address, infinite);
    return ();
}

@external
func test__execute__should_make_all_calls_and_return_concat_results{
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
