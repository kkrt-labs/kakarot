// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.accounts.library import GenericAccount, Account_kakarot_address, Account_evm_address
from starkware.starknet.common.syscalls import get_tx_info, get_caller_address, replace_class
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.alloc import alloc

@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, evm_address: felt) {
    Account_kakarot_address.write(kakarot_address);
    Account_evm_address.write(evm_address);
    return ();
}

// @title EVM smart contract account representation.

// @notice Initializes the account with the given Kakarot and EVM addresses.
// @param kakarot_address The address of the main Kakarot contract.
// @param evm_address The EVM address of the account.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(new_class: felt) {
    let (caller) = get_caller_address();
    let (kakarot_address) = Account_kakarot_address.read();
    with_attr error_message("Only Kakarot") {
        assert kakarot_address = caller;
    }
    replace_class(new_class);
    let (evm_address) = Account_evm_address.read();
    GenericAccount.initialize(kakarot_address, evm_address);
    return ();
}
