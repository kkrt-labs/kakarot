// SPDX-License-Identifier: MIT

%lang starknet

@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

@event
func kakarot_upgraded(new_class_hash: felt) {
}
