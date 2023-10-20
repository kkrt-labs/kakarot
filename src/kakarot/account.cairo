// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import hash_felts
from starkware.cairo.common.math_cmp import is_not_zero

from kakarot.accounts.library import Accounts
from kakarot.interfaces.interfaces import IAccount, IContractAccount, IERC20
from kakarot.model import model
from kakarot.constants import native_token_address, contract_account_class_hash
from utils.utils import Helpers
from utils.dict import default_dict_copy

namespace Account {
    // @dev Like an Account, but frozen after squashing all dicts
    struct Summary {
        address: felt,
        code_len: felt,
        code: felt*,
        storage_start: DictAccess*,
        storage: DictAccess*,
        nonce: felt,
        selfdestruct: felt,
    }

    // @notice Create a new account
    // @dev New contract accounts start at nonce=1.
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

    // @dev Copy the Account to safely mutate the storage
    // @param self The pointer to the Account
    func copy{range_check_ptr}(self: model.Account*) -> model.Account* {
        let (storage_start, storage) = default_dict_copy(self.storage_start, self.storage);
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

    // @dev Squash dicts used internally
    // @param self The pointer to the Account
    // @return a Summary Account, frozen
    func finalize{range_check_ptr}(self: model.Account*) -> Summary* {
        let (storage_start, storage) = default_dict_finalize(self.storage_start, self.storage, 0);
        return new Summary(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=storage_start,
            storage=storage,
            nonce=self.nonce,
            selfdestruct=self.selfdestruct,
        );
    }

    // @notice Commit the account to the storage backend at given address
    // @dev Account is deployed here if it doesn't exist already
    // @dev Works on Account.Summary to make sure only finalized accounts are committed.
    // @param self The pointer to the Account
    // @param starknet_address A starknet address to commit to
    // @notice Iterate through the storage dict and update the Starknet storage
    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: Summary*, starknet_address: felt
    ) {
        alloc_locals;

        let (registered_starknet_account) = Accounts.get_starknet_address(self.address);
        let starknet_account_exists = is_not_zero(registered_starknet_account);

        // Case new Account
        if (starknet_account_exists == 0) {
            // Deploy accounts
            let (class_hash) = contract_account_class_hash.read();
            Accounts.create(class_hash, self.address);
            // Write bytecode
            IContractAccount.write_bytecode(starknet_address, self.code_len, self.code);
            // Set nonce
            IContractAccount.set_nonce(starknet_address, self.nonce);
            // Save storages
            Internals._save_storage(starknet_address, self.storage_start, self.storage);
            return ();
        }

        // Case SELFDESTRUCT
        if (self.selfdestruct != 0) {
            // SELFDESTRUCT
            // TODO: clean also the storage
            let (local erase_data: felt*) = alloc();
            Helpers.fill(self.code_len, erase_data, 0);
            IContractAccount.write_bytecode(
                contract_address=starknet_address, bytecode_len=self.code_len, bytecode=erase_data
            );
            return ();
        }

        // Set nonce
        IContractAccount.set_nonce(starknet_address, self.nonce);
        // Save storages
        Internals._save_storage(starknet_address, self.storage_start, self.storage);

        return ();
    }

    // @notice fetch an account from Starknet
    // @dev An non deployed account is just an empty account.
    // @param address the pointer to the Address
    // @return the account populated with Starknet data
    func fetch{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: model.Address*
    ) -> model.Account* {
        alloc_locals;
        let (local registered_starknet_account) = Accounts.get_starknet_address(address.evm);
        let (bytecode_len, bytecode) = Accounts.get_bytecode(address.evm);
        let starknet_account_exists = is_not_zero(registered_starknet_account);

        // Case touching a non deployed account (non registered EOA)
        if (starknet_account_exists == 0) {
            let account = Account.init(
                address=address.evm, code_len=bytecode_len, code=bytecode, nonce=0
            );
            return account;
        }

        // Case EOA
        // TODO: use supports interface instead of the bytecode_len proxy
        if (bytecode_len == 0) {
            let account = Account.init(
                address=address.evm, code_len=bytecode_len, code=bytecode, nonce=0
            );
            return account;
        }

        // Case CA
        let (nonce) = IContractAccount.get_nonce(contract_address=address.starknet);
        let account = Account.init(
            address=address.evm, code_len=bytecode_len, code=bytecode, nonce=nonce
        );
        return account;
    }

    // @notice Read a given storage
    // @dev Try to retrieve in the local Dict<Uint256*> first, if not already here
    //      read the contract storage and cache the result.
    // @param self The pointer to the execution Account.
    // @param address The pointer to the Address.
    // @param key The pointer to the storage key
    // @return The updated Account
    // @return The read value
    func read_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, address: model.Address*, key: Uint256*
    ) -> (model.Account*, Uint256) {
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

    // @notice Set the code of the Account
    // @dev The only reason to set code after creation is in deploy transaction where
    //      the account exists from the beginning for setting storages, but the
    //      deployed bytecode is known at the end (the return_data of the tx).
    // @param self The pointer to the Account.
    // @param code_len The len of the code
    // @param code The code array
    func set_code(self: model.Account*, code_len: felt, code: felt*) -> model.Account* {
        assert self.code_len = 0;
        return new model.Account(
            address=self.address,
            code_len=code_len,
            code=code,
            storage_start=self.storage_start,
            storage=self.storage,
            nonce=self.nonce,
            selfdestruct=self.selfdestruct,
        );
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
