// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@storage_var
func Kakarot_cairo1_helpers_class_hash() -> (res: felt) {
}

@storage_var
func Kakarot_native_token_address() -> (res: felt) {
}

@storage_var
func Kakarot_account_contract_class_hash() -> (value: felt) {
}

@storage_var
func Kakarot_uninitialized_account_class_hash() -> (res: felt) {
}

@storage_var
func Kakarot_evm_to_starknet_address(evm_address: felt) -> (starknet_address: felt) {
}

@storage_var
func Kakarot_coinbase() -> (res: felt) {
}

// @notice The base fee set for kakarot
// @dev There can only be one base fee for a given block. Thus, we use an index to manage two different base fees:
// - The base fee to use for the current block (index: 'current_block')
// - The base fee to applicable starting next block (index: 'next_block')
@storage_var
func Kakarot_base_fee(index: felt) -> ((base_fee: felt, block_number: felt),) {
}

@storage_var
func Kakarot_prev_randao() -> (res: Uint256) {
}

@storage_var
func Kakarot_block_gas_limit() -> (res: felt) {
}

@storage_var
func Kakarot_chain_id() -> (res: felt) {
}

@storage_var
func Kakarot_authorized_cairo_precompiles_callers(address: felt) -> (res: felt) {
}

@storage_var
func Kakarot_l1_messaging_contract_address() -> (res: felt) {
}
