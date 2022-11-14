// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// @title SmartContractAccount main library file.
// @notice This file contains the EVM smart contract account representation logic.
// @author @abdelhamidbakhta
// @custom:namespace ContractAccount

// Storage

@storage_var
func bytecode_(index: felt) -> (res: felt) {
}

@storage_var
func bytecode_len_() -> (res: felt) {
}

@storage_var
func storage_(key: Uint256) -> (value: Uint256) {
}
@storage_var
func is_initialized_() -> (res: felt) {
}

namespace ContractAccount {
    // @notice This function is used to initialize the smart contract account.
    // @param kakarot_address: The address of the Kakarot smart contract.
    // @param bytecode_len: The length of the smart contract bytecode.
    // @param bytecode: The bytecode of the smart contract.
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt, bytecode_len: felt, bytecode: felt*) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);
        // Store the bytecode.
        internal.write_bytecode(0, bytecode_len, bytecode);
        return ();
    }

    // @notice Store the bytecode of the contract.
    // @param bytecode_len: The length of the bytecode.
    // @param bytecode: The bytecode of the contract.
    func write_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) {
        // Access control check.
        Ownable.assert_only_owner();
        // Recursively store the bytecode.
        internal.write_bytecode(0, bytecode_len, bytecode);
        return ();
    }

    // @notice This function is used to get the bytecode of the smart contract.
    // @return bytecode_len: The lenght of the bytecode.
    // @return bytecode: The bytecode of the smart contract.
    func bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        // Read bytecode length from storage.
        let (bytecode_len) = bytecode_len_.read();
        // Recursively load bytecode into specified memory location.
        let bytecode_: felt* = alloc();
        internal.load_bytecode(0, bytecode_len, bytecode_);
        return (bytecode_len, bytecode_);
    }

    // @notice This function is used to read the storage at a key.
    // @param key: The key to the stored value .
    // @return value: The store value.
    func storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(key: Uint256) -> (value: Uint256) {
        let value = storage_.read(key);
        return value;
    }

    // @notice This function is used to write to the storage of the account.
    // @param key: The key to the value to store.
    // @param value: The value to store.
    func write_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(key: Uint256, value: Uint256) {
        // Access control check.
        Ownable.assert_only_owner();
        // Write State
        storage_.write(key, value);
        return ();
    }

    // @notice This function checks if the account was initialized.
    // @return is_initialized: 1 if the account has been initialized 0 otherwise.
    func is_initialized{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (is_initialized: felt) {
        let is_initialized: felt = is_initialized_.read();
        return (is_initialized=is_initialized);
    }

    // @notice This function is used to initialized the smart contract.
    func initialize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() {
        // Access control check.
        Ownable.assert_only_owner();
        // initialize Evm contract
        is_initialized_.write(1);
        return ();
    }
}

namespace internal {
    // @notice Store the bytecode of the contract.
    // @param index: The index in the bytecode.
    // @param bytecode_len: The length of the bytecode.
    // @param bytecode: The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, bytecode_len: felt, bytecode: felt*
    ) {
        alloc_locals;
        if (index == bytecode_len) {
            bytecode_len_.write(bytecode_len);
            return ();
        }
        bytecode_.write(index, bytecode[index]);
        write_bytecode(index + 1, bytecode_len, bytecode);
        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index: The index in the bytecode.
    // @param bytecode_len: The length of the bytecode.
    // @param bytecode: The bytecode of the contract.
    func load_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(index: felt, bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        if (index == bytecode_len) {
            return ();
        }
        let (value) = bytecode_.read(index);
        assert [bytecode + index] = value;

        load_bytecode(index + 1, bytecode_len, bytecode);
        return ();
    }
}
