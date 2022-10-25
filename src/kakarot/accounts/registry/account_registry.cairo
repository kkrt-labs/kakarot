// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.accounts.registry.library import AccountRegistry

// @title EVM account registry contract.
// @author @abdelhamidbakhta

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt) {
    return AccountRegistry.constructor(kakarot_address);
}

// @notice Update or create an entry in the registry.
// @param starknet_address: The StarkNet address of the account.
// @param evm_address: The EVM address of the account.
@external
func set_account_entry{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(starknet_address: felt, evm_address: felt) {
    return AccountRegistry.set_account_entry(starknet_address, evm_address);
}

// @notice Get the starknet address of an EVM address.
// @param evm_address: The EVM address.
// @return starknet_address: The starknet address.
@view
func get_starknet_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) -> (starknet_address: felt) {
    return AccountRegistry.get_starknet_address(evm_address);
}

// @notice Get the EVM address of a starknet address.
// @param starknet_address: The starknet address.
// @return evm_address: The EVM address.
@view
func get_evm_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(starknet_address: felt) -> (evm_address: felt) {
    return AccountRegistry.get_evm_address(starknet_address);
}
