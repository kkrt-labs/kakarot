// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    library_call,
    library_call_l1_handler,
    get_caller_address,
)

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
    evm_address: felt
) {
    let (kakarot_address) = get_caller_address();
    let (implementation_class) = IKakarot.get_account_contract_class_hash(kakarot_address);

    IAccount.library_call_initialize(
        implementation_class,
        kakarot_address=kakarot_address,
        evm_address=evm_address,
        implementation_class=implementation_class,
    );

    return ();
}

//
// Fallback functions
//

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    let (kakarot_address) = Ownable.owner();
    let (class_hash) = IKakarot.get_account_contract_class_hash(kakarot_address);

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return (retdata_size, retdata);
}

@l1_handler
@raw_input
func __l1_default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) {
    let (kakarot_address) = Ownable.owner();
    let (class_hash) = IKakarot.get_account_contract_class_hash(kakarot_address);

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}
