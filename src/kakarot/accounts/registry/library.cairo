// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy

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

@storage_var
func salt() -> (value: felt) {
}

@storage_var
func EVM_contract_class_hash() -> (value: felt) {
}

namespace AccountRegistry {
    // @notice This function is used to initialize the registry.
    // @param kakarot_address: The address of the Kakarot smart contract.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt, evm_contract_class_hash: felt) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);
        EVM_contract_class_hash.write(evm_contract_class_hash);
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

    // @notice Deploy the starknetcontract holding the evm code
    // @param bytes: byte code stored in the new contract
    // @return evm_contract_address: address that is mapped to the actual new contract address
    @external
    func deploy_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytes_len: felt, bytes: felt*
    ) -> felt {
        alloc_locals;
        let (current_salt) = salt.read();
        let (class_hash) = EVM_contract_class_hash.read();

        let (local calldata: felt*) = alloc();
        assert [calldata] = bytes_len;
        memcpy(dst=calldata + 1, src=bytes, len=bytes_len);

        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=bytes_len + 1,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE,
        );
        salt.write(value=current_salt + 1);
        // Generate EVM_contract address from the new cairo contract
        // let (evm_contract_address,_) = unsigned_div_rem(contract_address, 1000000000000000000000000000000000000000000000000);
        let evm_contract_address = 123;
        
        //Save address of new contracts
        starknet_address_.write(evm_contract_address, contract_address);
        evm_address_.write(contract_address, evm_contract_address);
        return (evm_contract_address);
    }
}
