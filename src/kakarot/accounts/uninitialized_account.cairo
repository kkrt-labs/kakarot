// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, replace_class, library_call

@contract_interface
namespace IKakarot {
    func get_account_contract_class_hash() -> (account_contract_class_hash: felt) {
    }
}

@contract_interface
namespace IAccount {
    func initialize(kakarot_address: felt, evm_address: felt, implementation_class: felt) {
    }
}

// @title Uninitialized Contract Account. Used to get a deterministic address for an account, no
// matter the actual implementation class used.

// @notice Deploy and initialize the account with the Kakarot and EVM addresses it was deployed with.
// @param kakarot_address The address of the main Kakarot contract.
// @param evm_address The address of the EVM contract.
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    kakarot_address: felt, evm_address: felt
) {
    let (implementation_class) = IKakarot.get_account_contract_class_hash(kakarot_address);

    IAccount.library_call_initialize(
        implementation_class,
        kakarot_address=kakarot_address,
        evm_address=evm_address,
        implementation_class=implementation_class,
    );

    replace_class(implementation_class);
    return ();
}
