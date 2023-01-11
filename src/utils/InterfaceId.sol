// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract InterfaceIDCaculator {
    function getInterfaceId() pure public returns (bytes4) {
        bytes4 validate = bytes4(keccak256("__validate__(call_array_len: felt, call_array: ExternallyOwnedAccount.CallArray*, calldata_len: felt, calldata: felt*)"));
        bytes4 validate_declare =  bytes4(keccak256("__validate_declare__(class_hash: felt)"));
        bytes4 execute =  bytes4(keccak256("__execute__(call_array_len: felt, call_array: ExternallyOwnedAccount.CallArray*, calldata_len: felt, calldata: felt*)"));
        bytes4 get_eth_address = bytes4(keccak256("get_eth_address()"));
        bytes4 supports_interface = bytes4(keccak256("supports_inteface(interface_id: felt)"));
        bytes4 is_valid_signature = bytes4(keccak256("is_valid_signature(hash_len: felt, hash: felt*, signature_len: felt, signature: felt*)"));
        return validate ^ validate_declare ^ execute ^ get_eth_address ^ supports_interface ^ is_valid_signature;
    }
}