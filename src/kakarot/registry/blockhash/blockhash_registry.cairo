// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from kakarot.registry.blockhash.library import BlockhashRegistry

// @title Blockhash registry contract.
// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    return BlockhashRegistry.constructor(owner);
}

// @notice Transfer ownership of the registry to a new starknet address
// @param new_address The new owner of the blockhash registry
@external
func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    Ownable.assert_only_owner();
    BlockhashRegistry.transfer_ownership(new_address);
    return ();
}

// @notice Update or create an entry in the registry.
// @param block_number_len The length of block numbers.
// @param block_number The block numbers.
// @param block_hash_len The length of block hashes.
// @param block_hash The block hashes.
@external
func set_blockhashes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    block_number_len: felt, block_number: Uint256*, block_hash_len: felt, block_hash: felt*
) {
    Ownable.assert_only_owner();
    BlockhashRegistry.set_blockhashes(block_number_len, block_number, block_hash_len, block_hash);
    return ();
}

// @notice Get the blockhash of a certain block number.
// @param block_number The block number.
// @return blockhash The block hash.
@view
func get_blockhash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    block_number: Uint256
) -> (blockhash: felt) {
    return BlockhashRegistry.get_blockhash(block_number);
}
