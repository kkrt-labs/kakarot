// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.library import Kakarot
from kakarot.instructions.sha3_operation import Sha3Operation
// Constructor

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(owner: felt) {
    return Kakarot.constructor(owner);
}

@view
func sha3_inner{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    elements_len: felt, elements: Uint256*
) -> (res: Uint256) {
    return (res=Sha3Operation.sha3_inner(elements_len, elements));
}
