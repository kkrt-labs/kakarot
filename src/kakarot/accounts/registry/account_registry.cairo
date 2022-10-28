// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.accounts.registry.library import AccountRegistry

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, evm_contract_class_hash: felt) {
    return AccountRegistry.init(kakarot_address,evm_contract_class_hash);
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

// @notice deploy starknet contract
// @dev starknet contract will be mapped to an evm address that is also generated within this function
// @param bytes: the contract code
// @return evm address that is mapped to the actual contract address
@external
func deploy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    kakarot_address: felt, bytes_len: felt, bytes: felt*
) -> (evm_contract_address: felt) {
    let evm_contract_address = AccountRegistry.deploy_contract(bytes_len, bytes);
    return (evm_contract_address,);
}
