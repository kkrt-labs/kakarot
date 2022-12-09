// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.5.1 (upgrades/presets/Proxy.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    library_call,
    library_call_l1_handler,
    get_caller_address,
)

from openzeppelin.upgrades.library import Proxy
from openzeppelin.access.accesscontrol.library import AccessControl

const IMPLEMENTATION = 1641270636167208189312286704236493936886444818420034973493717770899220600387;  // implementation
const ADMIN = 1015500398948978605284530768271424158663964892192039972889799747543465927384;  // admin

//
// Views
//

// @notice Check whether a provided user has a specified role
// @param role - The role to query
// @param user - The address of the user
// @return has_role - Boolean to indicate whether user has the provided role
@view
func has_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    role: felt, user: felt
) -> (has_role: felt) {
    let (has_role) = AccessControl.has_role(role, user);
    return (has_role,);
}

// @notice Get the admin role that controlls another role
// @param role - The role from which to fetch the admin role
// @return admin_role - The role that governs the provided role
@view
func get_role_admin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    role: felt
) -> (admin_role: felt) {
    let (admin_role) = AccessControl.get_role_admin(role);
    return (admin_role,);
}

// @notice get the implemented contract hash
// @return implementation - The implementation contract hash
@view
func get_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation: felt
) {
    let (implementation) = Proxy.get_implementation_hash();
    return (implementation,);
}

// @dev Cairo doesn't support native decoding like Solidity yet,
//      that's why we pass three arguments for calldata instead of one
// @param implementation_hash the implementation contract hash
// @param selector the implementation initializer function selector
// @param calldata_len the calldata length for the initializer
// @param calldata an array of felt containing the raw calldata
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    implementation_hash: felt, selector: felt, calldata_len: felt, calldata: felt*
) {
    alloc_locals;
    AccessControl._set_role_admin(IMPLEMENTATION, ADMIN);
    // calldata[0] == owner
    AccessControl._grant_role(ADMIN, calldata[0]);
    AccessControl._grant_role(IMPLEMENTATION, calldata[0]);

    Proxy._set_implementation_hash(implementation_hash);

    if (selector != 0) {
        // Initialize proxy from implementation
        library_call(
            class_hash=implementation_hash,
            function_selector=selector,
            calldata_size=calldata_len,
            calldata=calldata,
        );
    }

    return ();
}

//
// Access Control functions
//

// @notice Allows the admin to transfer the admin role
// @param user - Address of the new admin
@external
func transfer_admin_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) {
    alloc_locals;
    AccessControl.assert_only_role(ADMIN);
    let (local caller) = get_caller_address();
    AccessControl._grant_role(ADMIN, user);
    AccessControl._revoke_role(ADMIN, caller);
    return ();
}

// @notice Grant the implementation role to a given address
// @param user - Address of the user who will receive the implementation role
@external
func grant_implementation_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user
) {
    AccessControl.assert_only_role(ADMIN);
    AccessControl._grant_role(IMPLEMENTATION, user);
    return ();
}

// @notice revoke the implementation role from a given address
// @param user - Address of the user will have the implementation role revoked
@external
func revoke_implementation_role{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user
) {
    AccessControl.assert_only_role(ADMIN);
    AccessControl._revoke_role(IMPLEMENTATION, user);
    return ();
}

//
// Implementation Control
//

// @notice set the implementation contract class hash for this proxy
// @param _new_implementation - The class hash of the implementation
@external
func set_implementation_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _new_implementation: felt
) {
    AccessControl.assert_only_role(IMPLEMENTATION);
    Proxy._set_implementation_hash(_new_implementation);
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
    let (class_hash) = Proxy.get_implementation_hash();

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
    let (class_hash) = Proxy.get_implementation_hash();

    library_call_l1_handler(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata,
    );
    return ();
}
