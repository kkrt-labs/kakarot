// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.accounts.eoa.library import ExternallyOwnedAccount

// @title EVM EOA account representation.
// @author @abdelhamidbakhta

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt) {
    return ExternallyOwnedAccount.constructor(kakarot_address);
}
