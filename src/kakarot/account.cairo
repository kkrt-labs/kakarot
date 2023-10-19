// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import emit_event
from starkware.cairo.common.uint256 import uint256_add, uint256_sub
from starkware.starknet.common.storage import normalize_address
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update, hash_felts

from kakarot.accounts.library import Accounts
from kakarot.interfaces.interfaces import IAccount, IContractAccount, IERC20
from kakarot.model import model
from kakarot.constants import native_token_address, contract_account_class_hash
from starkware.starknet.common.syscalls import call_contract
from utils.utils import Helpers

namespace Account {
    // @notice Create a new account
    // @dev New accounts start at nonce=1.
    // @param address The EVM address of the account
    // @param code_len The length of the code
    // @param code The pointer to the code
    // @param nonce The initial nonce
    // @return The updated state
    // @return The account
    func init(address: felt, code_len: felt, code: felt*, nonce: felt) -> model.Account* {
        let (storage_start) = default_dict_new(0);
        return new model.Account(
            address=address,
            code_len=code_len,
            code=code,
            storage_start=storage_start,
            storage=storage_start,
            nonce=nonce,
            selfdestruct=0,
        );
    }

    // @dev Squash dicts used internally
    // @param self The pointer to the Account
    func finalize{range_check_ptr}(self: model.Account*) -> model.Account* {
        let storage = self.storage;
        let (storage_start, storage) = default_dict_finalize(self.storage_start, self.storage, 0);
        return new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=storage_start,
            storage=storage,
            nonce=self.nonce,
            selfdestruct=self.selfdestruct,
        );
    }

    // @notice Read a given storage
    // @dev Try to retrieve in the local Dict<Uint256*> first, if not already here
    //      read the contract storage and cache the result.
    // @param self The pointer to the execution Account.
    // @param address The pointer to the Address.
    // @param key The pointer to the storage key
    // @return The updated Account
    // @return The read value
    func read_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.Account*, address: model.Address*, key: Uint256*) -> (model.Account*, Uint256) {
        alloc_locals;
        let storage = self.storage;
        let (local storage_key) = hash_felts{hash_ptr=pedersen_ptr}(cast(key, felt*), 2);

        let (pointer) = dict_read{dict_ptr=storage}(key=storage_key);

        if (pointer != 0) {
            // Return from local storage if found
            let value_ptr = cast(pointer, Uint256*);
            tempvar self = new model.Account(
                self.address,
                self.code_len,
                self.code,
                self.storage_start,
                storage,
                self.nonce,
                self.selfdestruct,
            );
            return (self, [value_ptr]);
        } else {
            // Otherwise regular read value from contract storage
            let (value) = IContractAccount.storage(contract_address=address.starknet, key=[key]);
            // Cache for possible later use (almost free and can save a lot)
            tempvar new_value = new Uint256(value.low, value.high);
            dict_write{dict_ptr=storage}(key=storage_key, new_value=cast(new_value, felt));
            tempvar self = new model.Account(
                self.address,
                self.code_len,
                self.code,
                self.storage_start,
                storage,
                self.nonce,
                self.selfdestruct,
            );
            return (self, value);
        }
    }

    // @notice Update a storage key with the given value
    // @param self The pointer to the Account.
    // @param key The pointer to the Uint256 storage key
    // @param value The pointer to the Uint256 value
    func write_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, key: Uint256*, value: Uint256*
    ) -> model.Account* {
        alloc_locals;
        local storage: DictAccess* = self.storage;
        let (storage_key) = hash_felts{hash_ptr=pedersen_ptr}(cast(key, felt*), 2);
        dict_write{dict_ptr=storage}(key=storage_key, new_value=cast(value, felt));
        tempvar self = new model.Account(
            self.address,
            self.code_len,
            self.code,
            self.storage_start,
            storage,
            self.nonce,
            self.selfdestruct,
        );
        return self;
    }

    // @notice Register an account for SELFDESTRUCT
    // @dev True means that the account will be erased at the end of the transaction
    // @return The pointer to the updated Account
    func selfdestruct(self: model.Account*) -> model.Account* {
        return new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=self.storage,
            nonce=self.nonce,
            selfdestruct=1,
        );
    }

    // @notice Commit the account to the storage backend at given address
    // @param self The pointer to the Account
    // @param starknet_address A starknet address to commit to
    // @notice Iterate through the accounts dict and update the Starknet storage
    // @dev Account is deployed here if it doesn't exist already
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, starknet_address: felt
    ) {
        alloc_locals;

        IContractAccount.set_nonce(starknet_address, self.nonce);
        Internals._save_storage(starknet_address, self.storage_start, self.storage);

        let (bytecode_len) = Accounts.get_bytecode_len(starknet_address);
        if (bytecode_len != 0) {
            // Just return because bytecode is immutable
            if (self.selfdestruct == 0) {
                return ();
            }

            // SELFDESTRUCT
            let (erase_data) = alloc();
            Helpers.fill(bytecode_len, erase_data, 0);
            // TODO: clean also the storage
            IContractAccount.write_bytecode(
                contract_address=starknet_address, bytecode_len=0, bytecode=erase_data
            );
            return ();
        }

        // Deploy accounts
        let (class_hash) = contract_account_class_hash.read();
        Accounts.create(class_hash, self.address);
        // Write bytecode
        IContractAccount.write_bytecode(starknet_address, self.code_len, self.code);

        return ();
    }
}

namespace Internals {
    // @notice Iterates through the storage dict and update Contract Account storage.
    // @param starknet_address The address of the Starknet account to save into.
    // @param storage_start The dict start pointer
    // @param storage_end The dict end pointer
    func _save_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        starknet_address: felt, storage_start: DictAccess*, storage_end: DictAccess*
    ) {
        if (storage_start == storage_end) {
            return ();
        }
        let key = cast(storage_start.key, Uint256*);
        let value = cast(storage_start.new_value, Uint256*);

        IContractAccount.write_storage(contract_address=starknet_address, key=[key], value=[value]);

        return _save_storage(starknet_address, storage_start + DictAccess.SIZE, storage_end);
    }
}
