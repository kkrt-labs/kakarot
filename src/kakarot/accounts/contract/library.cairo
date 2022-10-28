// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

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

namespace ContractAccount {
    // @notice This function is used to initialize the smart contract account.
    // @param kakarot_address: The address of the Kakarot smart contract.
    // @param code: The code of the smart contract.
    // @param code_len: The length of the smart contract code.
    func init{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address: felt, code_len: felt, code: felt*) {
        // Initialize access control.
        Ownable.initializer(kakarot_address);

        // Store the bytecode.
        store_code(code_len, code);

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
        // Recursively store the code.
        internal.store_code(0, code_len - 1, code);
        return ();
    }

    // @notice This function is used to get the code of the smart contract.
    // @return The code of the smart contract.
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
        internal.load_code(0, code_len - 1, code);
        return (code_len, code);
    }
}

namespace internal {
    // @notice Store the bytecode of the contract.
    // @param index: The index in the code.
    // @param code: The bytecode of the contract.
    // @param code_len: The length of the bytecode.
    func store_code{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(index: felt, last_index: felt, code: felt*) {
        alloc_locals;
        if (index == last_index) {
            return ();
        }
        code_.write(index, code[index]);
        store_code(index + 1, last_index, code);
        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index: The index in the code.
    // @param code: The bytecode of the contract.
    // @param code_len: The length of the bytecode.
    func load_code{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(index: felt, last_index: felt, code: felt*) {
        alloc_locals;
        if (index == last_index) {
            return ();
        }
        let (value) = code_.read(index);
        assert [code + index] = value;
        load_code(index + 1, last_index, code);
        return ();
    }
}
