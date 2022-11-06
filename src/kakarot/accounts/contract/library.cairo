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
func code_(index: felt) -> (res: felt) {
}

@storage_var
func code_len_() -> (res: felt) {
}

@storage_var
func state_(key: Uint256) -> (value: Uint256) {
}

namespace ContractAccount {
    // @notice This function is used to initialize the smart contract account.
    // @param kakarot_address: The address of the Kakarot smart contract.
    // @param code: The bytecode stored in this smart contract.
    // @param code_len: The length of the smart contract bytecode.
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt, code_len: felt, code: felt*) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);

        // Store the bytecode.
        internal.store_code(0, code_len, code);

        return ();
    }

    // @notice Store the bytecode of the contract.
    // @param code: The bytecode of the contract.
    // @param code_len: The length of the bytecode.
    func store_code{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(code_len: felt, code: felt*) {
        // Access control check.
        Ownable.assert_only_owner();
        // Recursively store the bytecode.
        internal.store_code(0, code_len, code);
        return ();
    }

    // @notice This function is used to get the bytecode of the smart contract.
    // @return The bytecode of the smart contract.
    func code{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (code_len: felt, code: felt*) {
        alloc_locals;
        let code: felt* = alloc();
        // Read code length from storage.
        let (code_len) = code_len_.read();
        // Recursively load code into specified memory location.
        internal.load_code(0, code_len, code);
        return (code_len, code);
    }

    // @notice read the contract state
    // @dev read a storage value from the contract given a specific storage key
    // @param key The key at which to fetch the storage value
    // @return The value which was stored at the given key value
    func read_state{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(key: Uint256) -> (value: Uint256) {
        let value = state_.read(key);
        return value;
    }

    // @notice write to the contract state
    // @dev write a value at a specific storage key
    // @param key The key at which to write the storage value
    // @param value The value to be stored 
    func write_state{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(key: Uint256, value: Uint256) {
        state_.write(key, value);
        return ();
    }
}

namespace internal {
    // @notice Store the bytecode of the contract.
    // @param index: The index at which to store the individual byte
    // @param code_len: The length of the bytecode.
    // @param code: The bytecode.
    func store_code{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, code_len: felt, code: felt*
    ) {
        alloc_locals;
        if (index == code_len) {
            code_len_.write(code_len);
            return ();
        }
        code_.write(index, code[index]);
        store_code(index + 1, code_len, code);
        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index: The index in the bytecode.
    // @param code: The bytecode of the contract.
    // @param code_len: The length of the bytecode.
    func load_code{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(index: felt, code_len: felt, code: felt*) {
        alloc_locals;
        if (index == code_len) {
            return ();
        }
        let (value) = code_.read(index);
        assert [code + index] = value;
        load_code(index + 1, code_len, code);
        return ();
    }
}
