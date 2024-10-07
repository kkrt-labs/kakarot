// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    library_call,
    library_call_l1_handler,
    get_caller_address,
    replace_class,
)

@contract_interface
namespace IOwner {
    func get_account_contract_class_hash() -> (account_contract_class_hash: felt) {
    }
}

const INITIALIZE_SELECTOR = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;

// @title Uninitialized Contract Account
// @dev Like a transparent proxy with a Owner, but pulling the implementation from the
//      Owner and calling `initialize` upon deployment.
// @param calldata_len The length of the calldata
// @param calldata The calldata of the initializer
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    let (owner_address) = get_caller_address();
    Ownable.initializer(owner_address);
    let (class_hash) = IOwner.get_account_contract_class_hash(owner_address);

    library_call(
        class_hash=class_hash,
        function_selector=INITIALIZE_SELECTOR,
        calldata_size=calldata_len,
        calldata=calldata,
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
    let (owner_address) = Ownable.owner();
    let (class_hash) = IOwner.get_account_contract_class_hash(owner_address);

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
    let (owner_address) = Ownable.owner();
    let (class_hash) = IOwner.get_account_contract_class_hash(owner_address);

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}

@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    return Ownable.owner();
}
