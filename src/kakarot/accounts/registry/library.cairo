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
func starknet_address_(evm_address: felt) -> (starknet_address: felt) {
}

@storage_var
func evm_address_(starknet_address: felt) -> (evm_address: felt) {
}

namespace AccountRegistry {
    // @notice This function is used to initialize the registry.
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

    // @notice Update or create an entry in the registry.
    // @param starknet_address: The StarkNet address of the account.
    // @param evm_address: The EVM address of the account.
    func set_account_entry{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_address: felt, evm_address: felt) {
        // Access control check.
        Ownable.assert_only_owner();

        // Update starknet address mapping.
        starknet_address_.write(evm_address, starknet_address);

        // Update evm address mapping.
        evm_address_.write(starknet_address, evm_address);

        return ();
    }

    // @notice Get the starknet address of an EVM address.
    // @param evm_address: The EVM address.
    // @return starknet_address: The starknet address.
    func get_starknet_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt) -> (starknet_address: felt) {
        let starknet_address = starknet_address_.read(evm_address);
        return starknet_address;
    }

    // @notice Get the EVM address of a starknet address.
    // @param starknet_address: The starknet address.
    // @return evm_address: The EVM address.
    func get_evm_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_address: felt) -> (evm_address: felt) {
        let evm_address = evm_address_.read(starknet_address);
        return evm_address;
    }

}
