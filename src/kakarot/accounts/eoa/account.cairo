// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address
)
from starkware.starknet.common.eth_utils import assert_eth_address_range
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.uint256 import Uint256
// Account library
from kakarot.accounts.eoa.library import KETHAA

@storage_var
func eth_address() -> (adress: felt) {
}


// Constructor
// @param ethAddress The Ethereum address which will control the account
@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(_eth_address: felt) {
    assert_eth_address_range(_eth_address);
    eth_address.write(_eth_address);
    return ();
}

// Account specific methods

// @notice validates a transaction
// @dev the transaction is considered as valid if is signed with the correct address and is a valid kakarot transaction
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata 
@external
func __validate__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(
    call_array_len: felt,
    call_array: KETHAA.CallArray*,
    calldata_len: felt,
    calldata: felt*
) {
    alloc_locals;
    let (address) = eth_address.read();
    KETHAA.are_valid_calls(eth_address=address,call_array_len=call_array_len,call_array=call_array,calldata_len=calldata_len,calldata=calldata);
    return ();
}

// @notice validates this account class for declaration
// @dev For our usecase the account doesn't need to declare contracts
@external
func __validate_declare__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr
} (
    class_hash: felt,
) {
    assert 1 = 0;
    return ();
}

// @notice executes the Kakarot transaction
// @dev this is executed only is the __validate__ function succeeded
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata 
// @return response_len The length of the response array
// @return response The response from the kakarot contract
@external
func __execute__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(
    call_array_len: felt,
    call_array: KETHAA.CallArray*,
    calldata_len: felt,
    calldata: felt*
) -> (
    response_len: felt,
    response: felt*
) {
    let (response: felt*) = alloc();
    // TODO: redirect calls
    return (response_len=0,response=response);
}

// @return eth_address The Ethereum address controlling this account 
@view
func get_eth_address{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
} () -> (eth_address: felt) {
    let (address) = eth_address.read();
    return (eth_address=address);
}

// @dev returns true if the interface_id is supported
// @dev TODO: check what interfaces the contract should support and maybe create one for a kakarot account
// @param interface_id The interface Id to verify if supported
@view
func supports_interface{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
} (interface_id: felt) -> (success: felt) {
    if(interface_id == KETHAA.AA_VERSION) {
        return (success=1);
    }
    return (success=0);
}

// @notice checks if the signature is valid
// @dev returns true if the signature is signed by the account controller
// @param hash_len The hash length which was signed
// @param hash The hash [low_128_bits, high_128_bits]
// @param signature_len The length of the signature array
// @param signature The array of the ethereum signature (as v, r, s)
@view
func is_valid_signature{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(
    hash_len: felt, // should be 2
    hash: felt*, // should be [low, high]
    signature_len: felt,
    signature: felt*
) -> (is_valid: felt) {
    alloc_locals;
    let (_eth_address) = eth_address.read();
    let v: felt = signature[0];
    let r: Uint256 = Uint256(low=signature[1], high=signature[2]);
    let s: Uint256 = Uint256(low=signature[3], high=signature[4]);
    let msg_hash: Uint256 = Uint256(low=hash[0], high=hash[1]);
    let (is_valid) = KETHAA.is_valid_eth_signature(msg_hash, r, s,v, _eth_address);
    return (is_valid=is_valid);
}