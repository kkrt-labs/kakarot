// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash_state import (
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash_update_with_hashchain,
)
from starkware.starknet.common.storage import normalize_address
from starkware.starknet.common.syscalls import get_contract_address, deploy
from starkware.cairo.common.registers import get_label_location

// Constants
const CONTRACT_ADDRESS_PREFIX = 'STARKNET_CONTRACT_ADDRESS';
const AA_VERSION = 0x11F2231B9D464344B81D536A50553D6281A9FA0FA37EF9AC2B9E076729AEFAA;  // pedersen("KAKAROT_AA_V0.0.1")

// Storage
@storage_var
func account_abstraction_class_hash() -> (felt,) {
}

@storage_var
func kakarot_address() -> (felt,) {
}

// Constructor
// @dev Creates the deployer
// @param _account_abstraction_class_hash The class_hash of the Abstraction Account Contract
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _account_abstraction_class_hash: felt, _kakarot_address: felt
) {
    account_abstraction_class_hash.write(_account_abstraction_class_hash);
    kakarot_address.write(_kakarot_address);
    return ();
}

// @notice deploys a new EVM account
// @dev deploys an instance of the Abstraction Account
// @param evm_address The Ethereum address which will be controlling the account
@external
func create_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> () {
    let (constructor_calldata: felt*) = alloc();
    let (_kakarot_address: felt) = kakarot_address.read();
    assert constructor_calldata[0] = evm_address;
    assert constructor_calldata[1] = _kakarot_address;
    let (class_hash) = account_abstraction_class_hash.read();
    let (account_address) = deploy(
        class_hash,
        contract_address_salt=AA_VERSION,
        constructor_calldata_size=2,
        constructor_calldata=constructor_calldata,
        deploy_from_zero=0,
    );
    return ();
}

// Getters

// @notice computes the starknet address from the evm address
// @dev As contract addresses are deterministic we can know what will be the address of a starknet contract from it's inputted EVM address
// @dev Adapted code from: https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo
// @param evm_addres The EVM address to transform to a starknet address
// @return contract_address The Starknet Account Contract address (not necessarily deployed)
@view
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    alloc_locals;
    let (deployer_address) = get_contract_address();
    let (_kakarot_address: felt) = kakarot_address.read();
    let (constructor_calldata: felt*) = alloc();
    assert constructor_calldata[0] = evm_address;
    assert constructor_calldata[1] = _kakarot_address;
    let (class_hash) = account_abstraction_class_hash.read();
    let (hash_state_ptr) = hash_init();
    let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr, item=CONTRACT_ADDRESS_PREFIX
    );
    let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr, item=deployer_address
    );
    let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr, item=AA_VERSION
    );
    let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr, item=class_hash
    );
    let (hash_state_ptr) = hash_update_with_hashchain{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr, data_ptr=constructor_calldata, data_length=2
    );
    let (contract_address_before_modulo) = hash_finalize{hash_ptr=pedersen_ptr}(
        hash_state_ptr=hash_state_ptr
    );
    let (contract_address) = normalize_address{range_check_ptr=range_check_ptr}(
        addr=contract_address_before_modulo
    );

    return (contract_address=contract_address);
}
