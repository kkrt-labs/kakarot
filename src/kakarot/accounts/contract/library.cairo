// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, split_felt
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import deploy as deploy_syscall
from starkware.starknet.common.syscalls import get_contract_address

from kakarot.constants import native_token_address, registry_address, evm_contract_class_hash
from kakarot.accounts.registry.library import AccountRegistry

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

// An event emitted whenever kakarot deploys a evm contract
// evm_contract_address is the representation of the evm address of the contract
// starknet_contract_address if the starknet address of the contract
@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

// Define the number of bytes per felt. Above 16, the following code won't work as it uses unsigned_div_rem
// which is bounded by RC_BOUND = 2 ** 128 ~ uint128 ~ bytes16
const byte_size = 16;

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
        internal.write_bytecode(0, bytecode_len, bytecode, 0, byte_size);
        return ();
    }

    // @notice This function is a factory to handle salt and registration of EVM<>Starknet binding.
    // @param salt: The salt for computing the corresponding EVM address
    func deploy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(salt: felt) -> (evm_contract_address: felt, starknet_contract_address: felt) {
        alloc_locals;

        // Prepare constructor data
        let (local calldata: felt*) = alloc();
        let (kakarot_address) = get_contract_address();
        assert [calldata] = kakarot_address;
        assert [calldata + 1] = 0;

        // Deploy contract account with no bytecode
        let (class_hash) = evm_contract_class_hash.read();
        let (starknet_contract_address) = deploy_syscall(
            class_hash=class_hash,
            contract_address_salt=salt,
            constructor_calldata_size=2,
            constructor_calldata=calldata,
            deploy_from_zero=0,
        );

        // Generate EVM_contract address from the new cairo contract
        // TODO: Use RLP to compute proper EVM address, see https://www.evm.codes/#f0
        let (_, low) = split_felt(starknet_contract_address);
        local evm_contract_address = 0xAbdE100700000000000000000000000000000000 + low;

        evm_contract_deployed.emit(
            evm_contract_address=evm_contract_address,
            starknet_contract_address=starknet_contract_address,
        );

        // Save address of new contracts
        let (reg_address) = registry_address.read();
        AccountRegistry.set_account_entry(
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
        );

        return (evm_contract_address, starknet_contract_address);
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
            remaining_shift=byte_size,
        );
        return ();
    }

    // @notice This function is used to get the bytecode_len of the smart contract.
    // @return bytecode_len: The lenght of the bytecode.
    func bytecode_len{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> felt {
        alloc_locals;
        let (_bytecode_len) = bytecode_len_.read();
        return _bytecode_len;
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
    // Use a precomputed 2 ** n array to save on resources usage.
    // Array starts with a 0 to be shifted and have pow[i] = bit shift for byte i with
    // i as a counter, ie i \in (0, byte_size]
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

    // @notice Store the bytecode of the contract.
    // @param index: The current free index in the bytecode_ storage.
    // @param bytecode_len: The length of the bytecode.
    // @param bytecode: The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt, bytecode_len: felt, bytecode: felt*, current_felt: felt, remaining_shift: felt
    ) {
        alloc_locals;

        if (bytecode_len == 0) {
            // end of bytecode case, break loop storing latest "pending" packed felt
            bytecode_.write(index, current_felt);
            return ();
        }

        if (remaining_shift == 0) {
            // end of packed felt case, store current "pending" felt
            // continue loop with a new current_felt and increament index in bytecode_ storage
            bytecode_.write(index, current_felt);
            return write_bytecode(index + 1, bytecode_len, bytecode, 0, byte_size);
        }

        // retrieve the precomputed pow array
        let (pow_address) = get_label_location(pow_);
        let pow = cast(pow_address, felt*);

        // shift the current byte and add it to the current felt
        // bytes are stored big endian, ie that 3 bytes ends up being stored as a felt whose reprensetation is 0xabcdef000...000
        // for a given remaining_shift:
        // current_felt = 0x 12 34 00 00...00 00
        // bytecode = 0x 56
        // pow[remaining_shift] * bytecode = 0x 00 00 56 00...00 00
        // resulting in 0x 12 34 56 00...00 00
        let current_felt = pow[remaining_shift] * [bytecode] + current_felt;

        return write_bytecode(
            index, bytecode_len - 1, bytecode + 1, current_felt, remaining_shift - 1
        );
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
            // end of loop
            return ();
        }

        if (remaining_shift == 0) {
            // end of current packed felt, loading next stored felt and increase storage index
            let (current_felt) = bytecode_.read(index);
            return load_bytecode(index + 1, bytecode_len, bytecode, current_felt, byte_size);
        }

        // retrieve the precomputed pow array
        let (pow_address) = get_label_location(pow_);
        let pow = cast(pow_address, felt*);

        // get the leading (big endian) byte of the current_felt
        // reassign current_felt to the be remainder
        let (current_byte, current_felt) = unsigned_div_rem(current_felt, pow[remaining_shift]);
        // add byte to returned array
        assert [bytecode] = current_byte;

        return load_bytecode(
            index, bytecode_len - 1, bytecode + 1, current_felt, remaining_shift - 1
        );
    }
}
