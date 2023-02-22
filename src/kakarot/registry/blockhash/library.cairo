// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

// @title BlockhashRegistry main library file.
// @notice This file contains logic for the blockhash registry.
// @custom:namespace BlockhashRegistry

// Storage
@storage_var
func blockhash_(block_number: Uint256) -> (blockhash: felt) {
}

namespace BlockhashRegistry {
    // @notice Initialize the registry.
    // @dev Set the kakarot smart contract as the owner.
    // @param kakarot_address The address of the Kakarot smart contract.
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        kakarot_address: felt
    ) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);
        return ();
    }

    // @notice Transfer ownership of the registry to a new starknet address.
    // @param new_owner The new owner of the blockhash registry.
    func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_owner: felt
    ) {
        Ownable.transfer_ownership(new_owner);
        return ();
    }

    // @notice Update or create an entry in the registry.
    // @param block_number_len The length of block numbers.
    // @param block_number The block numbers.
    // @param block_hash_len The length of block hashes.
    // @param block_hash The block hashes.
    func set_blockhashes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        block_number_len: felt, block_number: Uint256*, block_hash_len: felt, block_hash: felt*
    ) {
        with_attr error_message(
                "BlockhashRegistry: blockhash keys and values arrays must be of same length") {
            if (block_number_len != block_hash_len) {
                assert 1 = 0;
            }
        }

        if (block_number_len == 0) {
            return ();
        }

        // Update blockhash mapping.
        blockhash_.write(block_number=[block_number], value=[block_hash]);

        // Recurse
        set_blockhashes(block_number_len - 1, &block_number[1], block_hash_len - 1, block_hash + 1);

        return ();
    }

    // @notice Get the blockhash of a certain block number.
    // @param block_number The block number
    // @return blockhash The block hash.
    func get_blockhash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        block_number: Uint256
    ) -> (blockhash: felt) {
        let blockhash = blockhash_.read(block_number);
        return blockhash;
    }
}
