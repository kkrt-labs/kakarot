// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.registers import get_label_location

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
        internal.write_bytecode(0, bytecode_len, bytecode, 0, 16);
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
        bytecode_len_.write(bytecode_len);
        internal.write_bytecode(
            index=0,
            bytecode_len=bytecode_len,
            bytecode=bytecode,
            current_felt=0,
            remaining_shift=16,
        );
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
        internal.load_bytecode(
            index=0,
            bytecode_len=bytecode_len,
            bytecode=bytecode_,
            current_felt=0,
            remaining_shift=0,
        );
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
    // @param index: The index in the bytecode_stored.
    // @param bytecode_len: The length of the bytecode.
    // @param bytecode: The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, bytecode_len: felt, bytecode: felt*, current_felt: felt, remaining_shift: felt
    ) {
        alloc_locals;

        if (bytecode_len == 0) {
            // end of bytecode case
            bytecode_.write(index, current_felt);
            return ();
        }

        if (remaining_shift == 0) {
            // end of packed felt case
            bytecode_.write(index, current_felt);
            return write_bytecode(index + 1, bytecode_len, bytecode, 0, 16);
        }

        let (pow_address) = get_label_location(pow_);
        let pow = cast(pow_address, felt*);

        let current_felt = pow[remaining_shift] * [bytecode] + current_felt;

        return write_bytecode(
            index, bytecode_len - 1, bytecode + 1, current_felt, remaining_shift - 1
        );

        pow_:
        dw 0;
        dw 1;
        dw 2 ** 8;
        dw 2 ** 16;
        dw 2 ** 24;
        dw 2 ** 32;
        dw 2 ** 40;
        dw 2 ** 48;
        dw 2 ** 56;
        dw 2 ** 64;
        dw 2 ** 72;
        dw 2 ** 80;
        dw 2 ** 88;
        dw 2 ** 96;
        dw 2 ** 104;
        dw 2 ** 112;
        dw 2 ** 120;
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
    }(index: felt, bytecode_len: felt, bytecode: felt*, current_felt: felt, remaining_shift: felt) {
        alloc_locals;

        if (bytecode_len == 0) {
            return ();
        }

        if (remaining_shift == 0) {
            let (current_felt) = bytecode_.read(index);
            return load_bytecode(index + 1, bytecode_len, bytecode, current_felt, 16);
        }

        let (pow_address) = get_label_location(pow_);
        let pow = cast(pow_address, felt*);

        let (current_byte, current_felt) = unsigned_div_rem(current_felt, pow[remaining_shift]);
        assert [bytecode] = current_byte;

        return load_bytecode(
            index, bytecode_len - 1, bytecode + 1, current_felt, remaining_shift - 1
        );

        pow_:
        dw 0;
        dw 1;
        dw 2 ** 8;
        dw 2 ** 16;
        dw 2 ** 24;
        dw 2 ** 32;
        dw 2 ** 40;
        dw 2 ** 48;
        dw 2 ** 56;
        dw 2 ** 64;
        dw 2 ** 72;
        dw 2 ** 80;
        dw 2 ** 88;
        dw 2 ** 96;
        dw 2 ** 104;
        dw 2 ** 112;
        dw 2 ** 120;
    }
}
