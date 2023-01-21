// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.eth_utils import assert_eth_address_range
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.cairo.common.uint256 import Uint256
// Account library
from kakarot.accounts.eoa.aa.library import ExternallyOwnedAccount
from utils.rlp import RLP
from utils.utils import Helpers
from starkware.cairo.common.cairo_keccak.keccak import keccak, finalize_keccak, keccak_bigend
from starkware.cairo.common.math_cmp import is_le

@storage_var
func eth_address() -> (adress: felt) {
}

@storage_var
func kakarot_address() -> (address: felt) {
}

// Constructor
// @param _eth_address The Ethereum address which will control the account
// @param _kakarot_address The Starknet address of the Kakarot contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _eth_address: felt, _kakarot_address: felt
) {
    assert_eth_address_range(_eth_address);
    eth_address.write(_eth_address);
    kakarot_address.write(_kakarot_address);
    return ();
}

// Account specific methods

// @notice validate a transaction
// @dev the transaction is considered as valid if it is signed with the correct address and is a valid kakarot transaction
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata
@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(
    call_array_len: felt,
    call_array: ExternallyOwnedAccount.CallArray*,
    calldata_len: felt,
    calldata: felt*,
) {
    alloc_locals;
    let (address) = eth_address.read();
    ExternallyOwnedAccount.validate(
        eth_address=address,
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
    );
    return ();
}

// @notice validates this account class for declaration
// @dev For our usecase the account doesn't need to declare contracts
@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(class_hash: felt) {
    assert 1 = 0;
    return ();
}

// @notice executes the Kakarot transaction
// @dev this is executed only if the __validate__ function succeeded
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
    call_array: ExternallyOwnedAccount.CallArray*,
    calldata_len: felt,
    calldata: felt*,
) -> (response_len: felt, response: felt*) {
    let (response: felt*) = alloc();
    // TODO: parse, call kakarot, and format response
    return (response_len=0, response=response);
}

// @return eth_address The Ethereum address controlling this account
@view
func get_eth_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    eth_address: felt
) {
    let (address) = eth_address.read();
    return (eth_address=address);
}

// @dev returns true if the interface_id is supported
// @dev TODO: check what interfaces the contract should support and maybe create one for a kakarot account
// @param interface_id The interface Id to verify if supported
@view
func supports_interface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interface_id: felt
) -> (success: felt) {
    if (interface_id == ExternallyOwnedAccount.INTERFACE_ID) {
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
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(hash_len: felt, hash: felt*, signature_len: felt, signature: felt*) -> (is_valid: felt) {
    alloc_locals;
    let (_eth_address) = eth_address.read();
    return ExternallyOwnedAccount.is_valid_signature(
        _eth_address, hash_len, hash, signature_len, signature
    );
}

@view
func get_tx_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) -> (hash: Uint256, v: felt, r: Uint256, s: Uint256) {
    alloc_locals;
    let (local items: RLP.Item*) = alloc();
    // decode the rlp array
    RLP.decode_rlp(calldata_len, calldata, items);
    // legacy tx
    let data_len: felt = [items].data_len - 67;
    let (list_ptr: felt*) = alloc();
    let (rlp_len: felt) = RLP.encode_rlp_list(data_len, [items].data, list_ptr);
    let (keccak_ptr: felt*) = alloc();
    let keccak_ptr_start = keccak_ptr;
    let (words: felt*) = alloc();
    Helpers.bytes_to_bytes8_little_endian(
        bytes_len=rlp_len,
        bytes=list_ptr,
        index=0,
        size=rlp_len,
        bytes8=0,
        bytes8_shift=0,
        dest=words,
        dest_index=0,
    );
    let tx_hash = keccak_bigend{keccak_ptr=keccak_ptr}(inputs=words, n_bytes=rlp_len);
    let (local sub_items: RLP.Item*) = alloc();
    RLP.decode_rlp([items].data_len, [items].data, sub_items);
    let v = Helpers.bytes_to_felt(sub_items[6].data_len, sub_items[6].data, 0);
    let r = Helpers.bytes32_to_uint256(sub_items[7].data);
    let s = Helpers.bytes32_to_uint256(sub_items[8].data);
    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    // let (_eth_address) = eth_address.read();
    // ExternallyOwnedAccount.is_valid_eth_signature(tx_hash.res, r, s, v.n, _eth_address);
    return (hash=tx_hash.res, v=v.n, r=r, s=s);
}
