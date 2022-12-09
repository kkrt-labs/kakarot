// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// @title EVM account registry contract.
// @author @abdelhamidbakhta

// Local dependencies
from kakarot.accounts.registry.library import AccountRegistry

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt) {
    return AccountRegistry.constructor(kakarot_address);
}

// @notice Update or create an entry in the registry.
// @param starknet_contract_address: The StarkNet address of the account.
// @param evm_contract_address: The EVM address of the account.
@external
func set_account_entry{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(starknet_contract_address: felt, evm_contract_address: felt) {
    Ownable.assert_only_owner();
    return AccountRegistry.set_account_entry(
        starknet_contract_address=starknet_contract_address,
        evm_contract_address=evm_contract_address,
    );
}

// @notice Transfer ownership of the registry to a new starknet address
// @param new_address: The new owner of the account registry
@external
func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    Ownable.assert_only_owner();
    AccountRegistry.transfer_ownership(new_address);
    return ();
}

// @notice Get the starknet address of an EVM address.
// @param evm_contract_address: The EVM address.
// @return starknet_contract_address: The starknet address.
@view
func get_starknet_contract_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_contract_address: felt) -> (starknet_contract_address: felt) {
    return AccountRegistry.get_starknet_contract_address(evm_contract_address=evm_contract_address);
}

// @notice Get the EVM address of a starknet address.
// @param starknet_contract_address: The starknet address.
// @return evm_contract_address: The EVM address.
@view
func get_evm_contract_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(starknet_contract_address: felt) -> (evm_contract_address: felt) {
    return AccountRegistry.get_evm_contract_address(
        starknet_contract_address=starknet_contract_address
    );
}
