// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_le, uint256_eq
from starkware.cairo.common.bool import FALSE, TRUE

from kakarot.account import Account
from kakarot.model import model
from kakarot.gas import Gas
from utils.dict import default_dict_copy
from utils.utils import Helpers

namespace State {
    // @dev Create a new empty State
    func init() -> model.State* {
        let (accounts_start) = default_dict_new(0);
        let (events: model.Event*) = alloc();
        let (transfers: model.Transfer*) = alloc();
        return new model.State(
            accounts_start=accounts_start,
            accounts=accounts_start,
            events_len=0,
            events=events,
            transfers_len=0,
            transfers=transfers,
        );
    }

    // @dev Deep copy of the state, creating new memory segments
    // @param self The pointer to the State
    func copy{range_check_ptr, state: model.State*}() -> model.State* {
        alloc_locals;
        // accounts are a new memory segment
        let (accounts_start, accounts) = default_dict_copy(state.accounts_start, state.accounts);
        // for each account, storage is a new memory segment
        Internals._copy_accounts{accounts=accounts}(accounts_start, accounts);

        let (local events: felt*) = alloc();
        memcpy(dst=events, src=state.events, len=state.events_len * model.Event.SIZE);

        let (local transfers: felt*) = alloc();
        memcpy(dst=transfers, src=state.transfers, len=state.transfers_len * model.Transfer.SIZE);

        tempvar state_copy = new model.State(
            accounts_start=accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=cast(events, model.Event*),
            transfers_len=state.transfers_len,
            transfers=cast(transfers, model.Transfer*),
        );
        return state_copy;
    }

    // @dev Squash dicts used internally
    func finalize{range_check_ptr, state: model.State*}() {
        alloc_locals;
        // First squash to get only one account per key
        let (local accounts_start, accounts_end) = default_dict_finalize(
            state.accounts_start, state.accounts, 0
        );

        let (local accounts_copy: DictAccess*) = default_dict_new(0);
        tempvar accounts_copy_start = accounts_copy;
        // Squashes the storage dicts of accounts, and copy the result to a new memory segment.
        Internals._copy_accounts{accounts=accounts_copy}(accounts_start, accounts_end);

        tempvar state = new model.State(
            accounts_start=accounts_copy_start,
            accounts=accounts_copy,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );
        return ();
    }

    // @notice Get a given EVM Account
    // @dev Try to retrieve in the local Dict<Address*, Account*> first, and if not already here
    //      read the contract storage and cache the result.
    // @param evm_address The evm address of the Account
    // @return The updated state
    // @return The account
    func get_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(evm_address: felt) -> model.Account* {
        alloc_locals;
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=evm_address);

        // Return from local storage if found
        if (pointer != 0) {
            let account = cast(pointer, model.Account*);
            tempvar state = new model.State(
                accounts_start=state.accounts_start,
                accounts=accounts,
                events_len=state.events_len,
                events=state.events,
                transfers_len=state.transfers_len,
                transfers=state.transfers,
            );
            return account;
        } else {
            // Otherwise read values from contract storage
            local accounts: DictAccess* = accounts;
            let account = Account.fetch_or_create(evm_address);
            dict_write{dict_ptr=accounts}(key=evm_address, new_value=cast(account, felt));
            tempvar state = new model.State(
                accounts_start=state.accounts_start,
                accounts=accounts,
                events_len=state.events_len,
                events=state.events,
                transfers_len=state.transfers_len,
                transfers=state.transfers,
            );
            return account;
        }
    }

    // @notice Cache precompiles accounts in the state, making them warm.
    func cache_precompiles{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }() {
        alloc_locals;
        tempvar accounts_ptr = state.accounts;
        with accounts_ptr {
            Internals._cache_precompile(1);
            Internals._cache_precompile(2);
            Internals._cache_precompile(3);
            Internals._cache_precompile(4);
            Internals._cache_precompile(5);
            Internals._cache_precompile(6);
            Internals._cache_precompile(7);
            Internals._cache_precompile(8);
            Internals._cache_precompile(9);
        }
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts_ptr,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );

        return ();
    }

    // @notice Cache the addresses and storage keys from the access list
    //  in the state, making them warm.
    // @param access_list_len The length of the access list. Denotes the total number of `felts` in
    // the access list.
    // @param access_list The pointer to the access list.
    // @return The gas cost of caching the access list.
    func cache_access_list{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(access_list_len: felt, access_list: felt*) -> felt {
        alloc_locals;
        tempvar accounts_ptr = state.accounts;
        with accounts_ptr {
            let gas_cost = Internals._cache_access_list(access_list_len, access_list);
        }
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts_ptr,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );

        return gas_cost;
    }

    // @dev Checks if an address is warm (has been accessed before or in access list).
    // @param address The address to check.
    // @return A boolean indicating whether the address is warm.
    func is_account_warm{state: model.State*}(address: felt) -> felt {
        alloc_locals;
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=address);
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );

        // If not found in state, the account is not warm
        if (pointer != 0) {
            return TRUE;
        }
        return FALSE;
    }

    // @notice Checks if a storage slot is warm (has been accessed before) in an account.
    // @dev Since it reads the storage of the account, it will warm up both the account and the storage.
    // @param self The account to check.
    // @param key The key of the storage slot to check.
    // @return A boolean indicating whether the storage slot is warm.
    func is_storage_warm{pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*}(
        address: felt, key: Uint256*
    ) -> felt {
        alloc_locals;

        // Get the account
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=address);
        if (pointer == 0) {
            tempvar state = new model.State(
                accounts_start=state.accounts_start,
                accounts=accounts,
                events_len=state.events_len,
                events=state.events,
                transfers_len=state.transfers_len,
                transfers=state.transfers,
            );
            return FALSE;
        }

        let (account, res) = Account.is_storage_warm(cast(pointer, model.Account*), key);
        dict_write{dict_ptr=accounts}(key=account.address.evm, new_value=cast(account, felt));

        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );
        return res;
    }

    // @notice Updates the given account in the state.
    // @param account The new account
    func update_account{state: model.State*}(account: model.Account*) {
        let accounts = state.accounts;
        dict_write{dict_ptr=accounts}(key=account.address.evm, new_value=cast(account, felt));
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );
        return ();
    }

    // @notice Read a given storage
    // @dev Try to retrieve in the local Dict<Uint256*> first, if not already here
    //      read the contract storage and cache the result.
    // @param evm_address The evm address of the account to read storage from.
    // @param key The pointer to the storage key
    func read_storage{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(evm_address: felt, key: Uint256*) -> Uint256* {
        alloc_locals;
        let account = get_account(evm_address);
        let (account, value) = Account.read_storage(account, key);
        update_account(account);
        return value;
    }

    // @notice Update a storage key with the given value
    // @param evm_address The evm address of the account to write storage to.
    // @param key The pointer to the Uint256 storage key
    // @param value The pointer to the Uint256 value
    func write_storage{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(evm_address: felt, key: Uint256*, value: Uint256*) {
        alloc_locals;
        let account = get_account(evm_address);
        let account = Account.write_storage(account, key, value);
        update_account(account);
        return ();
    }

    // @notice Add an event to the Event* array
    // @param event The pointer to the Event
    // @return The updated State
    func add_event{state: model.State*}(event: model.Event) {
        assert state.events[state.events_len] = event;

        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=state.accounts,
            events_len=state.events_len + 1,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );
        return ();
    }

    // @notice Add a transfer to the Transfer* array
    // @param event The pointer to the Transfer
    // @return The updated State
    // @return The status of the transfer
    func add_transfer{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(transfer: model.Transfer) -> felt {
        alloc_locals;
        // See https://docs.cairo-lang.org/0.12.0/how_cairo_works/functions.html#retrieving-registers
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;

        if (transfer.sender == transfer.recipient) {
            return 1;
        }

        let (null_transfer) = uint256_eq(transfer.amount, Uint256(0, 0));
        if (null_transfer != 0) {
            return 1;
        }

        let sender = get_account(transfer.sender.evm);
        let (success) = uint256_le(transfer.amount, [sender.balance]);

        if (success == 0) {
            return success;
        }

        let recipient = get_account(transfer.recipient.evm);

        let (local sender_balance_new) = uint256_sub([sender.balance], transfer.amount);
        let (local recipient_balance_new, carry) = uint256_add(
            [recipient.balance], transfer.amount
        );

        let sender = Account.set_balance(sender, &sender_balance_new);
        let recipient = Account.set_balance(recipient, &recipient_balance_new);

        let accounts = state.accounts;
        dict_write{dict_ptr=accounts}(key=transfer.sender.evm, new_value=cast(sender, felt));
        dict_write{dict_ptr=accounts}(key=transfer.recipient.evm, new_value=cast(recipient, felt));
        assert state.transfers[state.transfers_len] = transfer;

        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len + 1,
            transfers=state.transfers,
        );
        return success;
    }

    // @notice Check whether an account is both in the state and non empty.
    // @param address EVM Address of the account that needs to be checked.
    // @return is_alive TRUE if the account is alive.
    func is_account_alive{state: model.State*}(address: felt) -> felt {
        alloc_locals;
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=address);
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );

        // If not found in local storage, the account is not alive
        if (pointer == 0) {
            return FALSE;
        }

        let account = cast(pointer, model.Account*);

        let nonce = account.nonce;
        let code_len = account.code_len;
        let balance = account.balance;

        // an account is alive if it has nonce, code or balance
        if (nonce + code_len + balance.low + balance.high != 0) {
            return TRUE;
        }

        return FALSE;
    }
}

namespace Internals {
    // @notice Iterate through the accounts dict and copy them
    // @dev Should be applied on a squashed dict
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _copy_accounts{range_check_ptr, accounts: DictAccess*}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        if (accounts_start == accounts_end) {
            return ();
        }

        if (accounts_start.new_value == 0) {
            // If we do a dict_read on an unexisting account, `prev_value` and `new_value` are set to 0.
            // However we expected pointers to model.Account, and casting 0 to model.Account* will
            // cause a "Memory address must be relocatable" error.
            return _copy_accounts(accounts_start + DictAccess.SIZE, accounts_end);
        }

        let account = cast(accounts_start.new_value, model.Account*);
        let account = Account.copy(account);
        dict_write{dict_ptr=accounts}(key=accounts_start.key, new_value=cast(account, felt));

        return _copy_accounts(accounts_start + DictAccess.SIZE, accounts_end);
    }

    func _cache_precompile{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, accounts_ptr: DictAccess*
    }(evm_address: felt) {
        alloc_locals;
        let starknet_address = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet=starknet_address, evm=evm_address);
        let balance = Account.fetch_balance(address);
        tempvar balance_ptr = new Uint256(balance.low, balance.high);
        let (bytecode) = alloc();
        let account = Account.init(
            address=address, code_len=0, code=bytecode, nonce=1, balance=balance_ptr
        );
        dict_write{dict_ptr=accounts_ptr}(key=address.evm, new_value=cast(account, felt));
        return ();
    }

    func _cache_access_list{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, accounts_ptr: DictAccess*
    }(access_list_len: felt, access_list: felt*) -> felt {
        alloc_locals;

        if (access_list_len == 0) {
            return 0;
        }

        let address = [access_list];
        let storage_keys_len = [access_list + 1];
        let account = Account.fetch_or_create(address);
        let account = Account.cache_storage_keys(
            account, storage_keys_len, cast(access_list + 2, Uint256*)
        );
        dict_write{dict_ptr=accounts_ptr}(key=address, new_value=cast(account, felt));

        // storage_keys_len tracks the count storage keys in the same array.
        // Each storage key takes 2 felt each
        tempvar item_len = 2 + storage_keys_len * 2;
        let cum_gas_cost = _cache_access_list(access_list_len - item_len, access_list + item_len);
        return cum_gas_cost + Gas.TX_ACCESS_LIST_ADDRESS_COST + storage_keys_len *
            Gas.TX_ACCESS_LIST_STORAGE_KEY_COST;
    }
}
