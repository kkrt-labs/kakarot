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

from kakarot.account import Account
from kakarot.model import model
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
        let (local accounts_start, accounts) = default_dict_finalize(
            state.accounts_start, state.accounts, 0
        );
        // Finalizing the accounts create another entry per account
        Internals._copy_accounts{accounts=accounts}(accounts_start, accounts);
        // Squash again to keep only one model.Account per key
        // @dev: using default_dict_copy as default_dict_finalize doesn't return a default_dict
        let (local accounts_start, accounts) = default_dict_copy(accounts_start, accounts);

        tempvar state = new model.State(
            accounts_start=accounts_start,
            accounts=accounts,
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
    // @param key The pointer to the address
    // @return The updated state
    // @return The account
    func get_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(address: model.Address*) -> model.Account* {
        alloc_locals;
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=address.evm);

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
            let account = Account.fetch_or_create(address);
            dict_write{dict_ptr=accounts}(key=address.evm, new_value=cast(account, felt));
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

    // @notice Set the Account at the given address
    // @param address The address of the Account
    // @param account The new account
    func set_account{state: model.State*}(address: model.Address*, account: model.Account*) {
        let accounts = state.accounts;
        dict_write{dict_ptr=accounts}(key=address.evm, new_value=cast(account, felt));
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
    // @param address The pointer to the Address.
    // @param key The pointer to the storage key
    func read_storage{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(address: model.Address*, key: Uint256*) -> Uint256* {
        alloc_locals;
        let account = get_account(address);
        let (account, value) = Account.read_storage(account, address, key);
        set_account(address, account);
        return value;
    }

    // @notice Update a storage key with the given value
    // @param address The pointer to the Account address
    // @param key The pointer to the Uint256 storage key
    // @param value The pointer to the Uint256 value
    func write_storage{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(address: model.Address*, key: Uint256*, value: Uint256*) {
        alloc_locals;
        let account = get_account(address);
        let account = Account.write_storage(account, key, value);
        set_account(address, account);
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

        let sender = get_account(transfer.sender);
        let (success) = uint256_le(transfer.amount, [sender.balance]);

        if (success == 0) {
            return success;
        }

        let recipient = get_account(transfer.recipient);

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
    // @param address Address of the account that needs to be checked.
    // @return is_alive TRUE if the account is alive.
    func is_account_alive{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(evm_address: felt) -> felt {
        alloc_locals;
        let accounts = state.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=evm_address);

        // If not found in local storage, the account is not alive
        if (pointer == 0) {
            return FALSE;
        }

        let account = cast(pointer, model.Account*);
        tempvar state = new model.State(
            accounts_start=state.accounts_start,
            accounts=accounts,
            events_len=state.events_len,
            events=state.events,
            transfers_len=state.transfers_len,
            transfers=state.transfers,
        );

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
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _copy_accounts{range_check_ptr, accounts: DictAccess*}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        if (accounts_start == accounts_end) {
            return ();
        }

        let account = cast(accounts_start.new_value, model.Account*);
        let account = Account.copy(account);
        dict_write{dict_ptr=accounts}(key=accounts_start.key, new_value=cast(account, felt));

        return _copy_accounts(accounts_start + DictAccess.SIZE, accounts_end);
    }
}
