%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import library_call, library_call_l1_handler

from kakarot.accounts.proxy.upgradable import _get_implementation, _set_implementation
from kakarot.constants import Constants

// ///////////////////
// CONSTRUCTOR
// ///////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

// ///////////////////
// EXTERNAL FUNCTIONS
// ///////////////////

// Using initializer because we need to remove implementation from constructor calldata
// to be able to compute starknet address for bot externally owned account and contract account.
// Should not be a security issue because initializer can be called only 1 time in implementation.
@external
func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    implementation: felt, calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    _set_implementation(implementation);
    library_call(
        class_hash=implementation,
        function_selector=Constants.INITIALIZE_SELECTOR,
        calldata_size=calldata_len,
        calldata=calldata,
    );
    return ();
}

@external
@raw_input
@raw_output
func __default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) -> (retdata_size: felt, retdata: felt*) {
    let (implementation) = _get_implementation();

    let (retdata_size: felt, retdata: felt*) = library_call(
        class_hash=implementation,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return (retdata_size=retdata_size, retdata=retdata);
}

@l1_handler
@raw_input
func __l1_default__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    selector: felt, calldata_size: felt, calldata: felt*
) {
    let (implementation) = _get_implementation();

    library_call_l1_handler(
        class_hash=implementation,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}

