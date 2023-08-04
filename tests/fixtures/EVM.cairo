// SPDX-License-Identifier: MIT
// Bare minimum contract for executing bytecode on the EVM interpreter

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

// Local dependencies
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack

from kakarot.constants import (
    native_token_address,
    contract_account_class_hash,
    blockhash_registry_address,
    account_proxy_class_hash,
    Constants,
)

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt,
    contract_account_class_hash_: felt,
    account_proxy_class_hash_: felt,
    blockhash_registry_address_: felt,
) {
    native_token_address.write(native_token_address_);
    contract_account_class_hash.write(contract_account_class_hash_);
    account_proxy_class_hash.write(account_proxy_class_hash_);
    blockhash_registry_address.write(blockhash_registry_address_);
    return ();
}

@external
func execute{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(value: felt, bytecode_len: felt, bytecode: felt*, calldata_len: felt, calldata: felt*) -> (
    stack_accesses_len: felt,
    stack_accesses: felt*,
    stack_len: felt,
    memory_accesses_len: felt,
    memory_accesses: felt*,
    memory_bytes_len: felt,
    starknet_contract_address: felt,
    evm_contract_address: felt,
    return_data_len: felt,
    return_data: felt*,
    gas_used: felt,
) {
    return Kakarot.execute(
        starknet_contract_address=0,
        evm_contract_address=0,
        origin=0,
        bytecode_len=bytecode_len,
        bytecode=bytecode,
        calldata_len=calldata_len,
        calldata=calldata,
        value=value,
        gas_limit=Constants.TRANSACTION_GAS_LIMIT,
        gas_price=0,
    );
}
