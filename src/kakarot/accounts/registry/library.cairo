// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// @title AccountRegistry main library file.
// @notice This file contains the EVM smart contract account representation logic.
// @author @abdelhamidbakhta
// @custom:namespace AccountRegistry

// Storage
@storage_var
func starknet_contract_address_(evm_contract_address: felt) -> (starknet_contract_address: felt) {
}

@storage_var
func evm_contract_address_(starknet_contract_address: felt) -> (evm_contract_address: felt) {
}

namespace AccountRegistry {
    // @notice This function is used to initialize the registry.
    // @dev Sets the kakarot smart contract as the owner
    // @param kakarot_address: The address of the Kakarot smart contract.
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);
        return ();
    }

    // @notice Transfer ownership of the registry to a new starknet address
    // @param new_owner The new owner of the account registry
    func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_owner: felt
    ) {
        // Access control check.
        Ownable.assert_only_owner();
        Ownable.transfer_ownership(new_owner);
        return ();
    }

    // @notice Update or create an entry in the registry.
    // @param starknet_contract_address: The StarkNet address of the account.
    // @param evm_contract_address: The EVM address of the account.
    func set_account_entry{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_contract_address: felt, evm_contract_address: felt) {
        // Access control check.
        Ownable.assert_only_owner();

        // Update starknet address mapping.
        starknet_contract_address_.write(evm_contract_address, starknet_contract_address);

        // Update evm address mapping.
        evm_contract_address_.write(starknet_contract_address, evm_contract_address);

        return ();
    }

    // @notice Get the starknet address of an EVM address.
    // @param evm_contract_address: The EVM address.
    // @return starknet_contract_address: The starknet address.
    func get_starknet_contract_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_contract_address: felt) -> (starknet_contract_address: felt) {
        let starknet_contract_address = starknet_contract_address_.read(evm_contract_address);
        return starknet_contract_address;
    }

    // @notice Get the EVM address of a starknet address.
    // @param starknet_contract_address: The starknet address.
    // @return evm_contract_address: The EVM address.
    func get_evm_contract_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_contract_address: felt) -> (evm_contract_address: felt) {
        let evm_contract_address = evm_contract_address_.read(starknet_contract_address);
        return evm_contract_address;
    }
}
