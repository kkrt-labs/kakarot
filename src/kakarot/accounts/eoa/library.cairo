// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// @title ExternallyOwnedAccount main library file.
// @notice This file contains the EVM EOA account representation logic.
// @author @abdelhamidbakhta
// @custom:namespace ExternallyOwnedAccount

namespace ExternallyOwnedAccount {
    // @notice This function is used to initialize the externally owned account.
    // @dev Sets the kakarot smart contract as the owner
    // @param kakarot_address: The address of the Kakarot smart contract.
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt) {
        Ownable.initializer(kakarot_address);
        return ();
    }
}
