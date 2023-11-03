// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update, hash_felts
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_le
from starkware.starknet.common.storage import normalize_address
from starkware.starknet.common.syscalls import call_contract
from starkware.starknet.common.syscalls import emit_event

from kakarot.account import Account
from kakarot.constants import native_token_address, contract_account_class_hash
from kakarot.interfaces.interfaces import IERC20
from kakarot.model import model
from utils.dict import default_dict_copy
from utils.utils import Helpers

namespace State {
    // @dev Like an State, but frozen after squashing all dicts
    struct Summary {
        accounts_start: DictAccess*,
        accounts: DictAccess*,
        events_len: felt,
        events: model.Event*,
        balances_start: DictAccess*,
        balances: DictAccess*,
        transfers_len: felt,
        transfers: model.Transfer*,
    }

    // @dev Create a new empty State
    func init() -> model.State* {
        let (accounts_start) = default_dict_new(0);
        let (balances_start) = default_dict_new(0);
        let (events: model.Event*) = alloc();
        let (transfers: model.Transfer*) = alloc();
        return new model.State(
            accounts_start=accounts_start,
            accounts=accounts_start,
            events_len=0,
            events=events,
            balances_start=balances_start,
            balances=balances_start,
            transfers_len=0,
            transfers=transfers,
        );
    }

    // @dev Deep copy of the state, creating new memory segments
    // @param self The pointer to the State
    func copy{range_check_ptr}(self: model.State*) -> model.State* {
        alloc_locals;
        // accounts are a new memory segment
        let (accounts_start, accounts) = default_dict_copy(self.accounts_start, self.accounts);
        // for each account, storage is a new memory segment
        Internals._copy_accounts{accounts=accounts}(accounts_start, accounts);

        // balances values are immutable so no need for an Internals._copy_balances
        let (balances_start, balances) = default_dict_copy(self.balances_start, self.balances);

        let (local events: felt*) = alloc();
        memcpy(dst=events, src=self.events, len=self.events_len * model.Event.SIZE);

        let (local transfers: felt*) = alloc();
        memcpy(dst=transfers, src=self.transfers, len=self.transfers_len * model.Transfer.SIZE);

        return new model.State(
            accounts_start=accounts_start,
            accounts=accounts,
            events_len=self.events_len,
            events=cast(events, model.Event*),
            balances_start=balances_start,
            balances=balances,
            transfers_len=self.transfers_len,
            transfers=cast(transfers, model.Transfer*),
        );
    }

    // @dev Squash dicts used internally
    // @param self The pointer to the State
    func finalize{range_check_ptr}(self: model.State*) -> Summary* {
        alloc_locals;
        // First squash to get only one account per key
        let (local accounts_start, accounts) = default_dict_finalize(
            self.accounts_start, self.accounts, 0
        );
        // Finalizing the accounts create another entry per account
        Internals._finalize_accounts{accounts=accounts}(accounts_start, accounts);
        // Squash again to keep only one Account.Summary per key
        let (local accounts_start, accounts) = default_dict_finalize(accounts_start, accounts, 0);

        let (balances_start, balances) = default_dict_finalize(
            self.balances_start, self.balances, 0
        );

        return new Summary(
            accounts_start=accounts_start,
            accounts=accounts,
            events_len=self.events_len,
            events=self.events,
            balances_start=balances_start,
            balances=balances,
            transfers_len=self.transfers_len,
            transfers=self.transfers,
        );
    }

    // @notice Commit the current state to the underlying data backend (here, Starknet)
    // @dev Works on State.Summary to make sure only finalized states are committed.
    // @param self The pointer to the State
    func commit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: Summary*) {
        // Accounts
        Internals._commit_accounts(self.accounts_start, self.accounts);

        // Events
        Internals._emit_events(self.events_len, self.events);

        // Transfers
        let (native_token_address_) = native_token_address.read();
        Internals._transfer_eth(native_token_address_, self.transfers_len, self.transfers);

        return ();
    }

    // @notice Get a given EVM Account
    // @dev Try to retrieve in the local Dict<Address*, Account*> first, and if not already here
    //      read the contract storage and cache the result.
    // @param self The pointer to the State.
    // @param key The pointer to the address
    // @return The updated state
    // @return The account
    func get_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.State*, address: model.Address*
    ) -> (model.State*, model.Account*) {
        alloc_locals;
        let accounts = self.accounts;
        let (pointer) = dict_read{dict_ptr=accounts}(key=address.starknet);

        // Return from local storage if found
        if (pointer != 0) {
            let account = cast(pointer, model.Account*);
            tempvar state = new model.State(
                accounts_start=self.accounts_start,
                accounts=accounts,
                events_len=self.events_len,
                events=self.events,
                balances_start=self.balances_start,
                balances=self.balances,
                transfers_len=self.transfers_len,
                transfers=self.transfers,
            );
            return (state, account);
        } else {
            // Otherwise read values from contract storage
            local accounts: DictAccess* = accounts;
            let account = Account.fetch_or_create(address);
            dict_write{dict_ptr=accounts}(key=address.starknet, new_value=cast(account, felt));
            tempvar state = new model.State(
                accounts_start=self.accounts_start,
                accounts=accounts,
                events_len=self.events_len,
                events=self.events,
                balances_start=self.balances_start,
                balances=self.balances,
                transfers_len=self.transfers_len,
                transfers=self.transfers,
            );
            return (state, account);
        }
    }

    // @notice Set the Account at the given address
    // @param self The pointer to the State.
    // @param address The address of the Account
    // @param account The new account
    func set_account(
        self: model.State*, address: model.Address*, account: model.Account*
    ) -> model.State* {
        let accounts = self.accounts;
        dict_write{dict_ptr=accounts}(key=address.starknet, new_value=cast(account, felt));
        return new model.State(
            accounts_start=self.accounts_start,
            accounts=accounts,
            events_len=self.events_len,
            events=self.events,
            balances_start=self.balances_start,
            balances=self.balances,
            transfers_len=self.transfers_len,
            transfers=self.transfers,
        );
    }

    // @notice Read a given storage
    // @dev Try to retrieve in the local Dict<Uint256*> first, if not already here
    //      read the contract storage and cache the result.
    // @param self The pointer to the execution State.
    // @param address The pointer to the Address.
    // @param key The pointer to the storage key
    func read_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.State*, address: model.Address*, key: Uint256*) -> (model.State*, Uint256*) {
        alloc_locals;
        let (self, account) = get_account(self, address);
        let (account, value) = Account.read_storage(account, address, key);
        let self = set_account(self, address, account);
        return (self, value);
    }

    // @notice Update a storage key with the given value
    // @param self The pointer to the State.
    // @param address The pointer to the Account address
    // @param key The pointer to the Uint256 storage key
    // @param value The pointer to the Uint256 value
    func write_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.State*, address: model.Address*, key: Uint256*, value: Uint256*
    ) -> model.State* {
        alloc_locals;
        let (self, account) = get_account(self, address);
        let account = Account.write_storage(account, key, value);
        let self = set_account(self, address, account);
        return self;
    }

    // @notice Add an event to the Event* array
    // @param self The pointer to the State
    // @param event The pointer to the Event
    // @return The updated State
    func add_event(self: model.State*, event: model.Event) -> model.State* {
        assert self.events[self.events_len] = event;

        return new model.State(
            accounts_start=self.accounts_start,
            accounts=self.accounts,
            events_len=self.events_len + 1,
            events=self.events,
            balances_start=self.balances_start,
            balances=self.balances,
            transfers_len=self.transfers_len,
            transfers=self.transfers,
        );
    }

    // @notice Add a transfer to the Transfer* array
    // @param self The pointer to the State
    // @param event The pointer to the Transfer
    // @return The updated State
    // @return The status of the transfer
    func add_transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.State*, transfer: model.Transfer) -> (model.State*, felt) {
        alloc_locals;
        // See https://docs.cairo-lang.org/0.12.0/how_cairo_works/functions.html#retrieving-registers
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;

        let (self, sender_balance_prev) = read_balance(self, transfer.sender);
        let (success) = uint256_le(transfer.amount, sender_balance_prev);

        if (success == 0) {
            return (self, success);
        }

        let (self, recipient_balance_prev) = read_balance(self, transfer.recipient);
        let (local sender_balance_new) = uint256_sub(sender_balance_prev, transfer.amount);
        let (local recipient_balance_new, carry) = uint256_add(
            recipient_balance_prev, transfer.amount
        );

        let balances = self.balances;
        dict_write{dict_ptr=balances}(
            key=transfer.sender.starknet, new_value=cast(&sender_balance_new, felt)
        );
        dict_write{dict_ptr=balances}(
            key=transfer.recipient.starknet, new_value=cast(&recipient_balance_new, felt)
        );
        assert self.transfers[self.transfers_len] = transfer;

        tempvar state = new model.State(
            accounts_start=self.accounts_start,
            accounts=self.accounts,
            events_len=self.events_len,
            events=self.events,
            balances_start=self.balances_start,
            balances=balances,
            transfers_len=self.transfers_len + 1,
            transfers=self.transfers,
        );
        return (state, success);
    }

    // @notice Get the balance of a given address
    // @dev Try to read from local dict, and read from ETH contract otherwise
    // @param self The pointer to the State
    // @param address The pointer to the Address
    func read_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.State*, address: model.Address*
    ) -> (state: model.State*, balance: Uint256) {
        let balances = self.balances;
        let (pointer) = dict_read{dict_ptr=balances}(key=address.starknet);
        if (pointer != 0) {
            let balance_ptr = cast(pointer, Uint256*);
            tempvar self = new model.State(
                accounts_start=self.accounts_start,
                accounts=self.accounts,
                events_len=self.events_len,
                events=self.events,
                balances_start=self.balances_start,
                balances=balances,
                transfers_len=self.transfers_len,
                transfers=self.transfers,
            );
            return (self, [balance_ptr]);
        } else {
            let (native_token_address_) = native_token_address.read();
            let (balance) = IERC20.balanceOf(native_token_address_, address.starknet);
            tempvar balance_ptr = new Uint256(balance.low, balance.high);
            dict_write{dict_ptr=balances}(key=address.starknet, new_value=cast(balance_ptr, felt));
            tempvar self = new model.State(
                accounts_start=self.accounts_start,
                accounts=self.accounts,
                events_len=self.events_len,
                events=self.events,
                balances_start=self.balances_start,
                balances=balances,
                transfers_len=self.transfers_len,
                transfers=self.transfers,
            );
            return (self, balance);
        }
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
        let account_summary = Account.copy(account);
        dict_write{dict_ptr=accounts}(
            key=accounts_start.key, new_value=cast(account_summary, felt)
        );

        return _copy_accounts(accounts_start + DictAccess.SIZE, accounts_end);
    }

    // @notice Iterate through the accounts dict and finalize them
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _finalize_accounts{range_check_ptr, accounts: DictAccess*}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        if (accounts_start == accounts_end) {
            return ();
        }

        let account = cast(accounts_start.new_value, model.Account*);
        let account_summary = Account.finalize(account);
        dict_write{dict_ptr=accounts}(
            key=accounts_start.key, new_value=cast(account_summary, felt)
        );

        return _finalize_accounts(accounts_start + DictAccess.SIZE, accounts_end);
    }

    // @notice Iterate through the accounts dict and commit them
    // @dev Account is deployed here if it doesn't exist already
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _commit_accounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        alloc_locals;
        if (accounts_start == accounts_end) {
            return ();
        }

        let starknet_address = accounts_start.key;
        let account = cast(accounts_start.new_value, Account.Summary*);
        Account.commit(account, starknet_address);

        _commit_accounts(accounts_start + DictAccess.SIZE, accounts_end);

        return ();
    }

    // @notice Iterates through a list of events and emits them.
    // @param events_len The length of the events array.
    // @param events The array of Event structs that are emitted via the `emit_event` syscall.
    func _emit_events{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        events_len: felt, events: model.Event*
    ) {
        alloc_locals;

        if (events_len == 0) {
            return ();
        }

        let event: model.Event = [events];
        emit_event(
            keys_len=event.topics_len, keys=event.topics, data_len=event.data_len, data=event.data
        );

        _emit_events(events_len - 1, events + model.Event.SIZE);
        return ();
    }

    // @notice Iterates through a list of Transfer and makes them
    // @dev Transfers are made last so as to have all accounts created beforehand.
    //      Kakarot is not authorized for accounts that are created and SELDESTRUCT in the same transaction
    // @param transfers_len The length of the transfers array.
    // @param transfers The array of Transfer.
    func _transfer_eth{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_address: felt, transfers_len: felt, transfers: model.Transfer*
    ) {
        if (transfers_len == 0) {
            return ();
        }

        let transfer = [transfers];
        IERC20.transferFrom(
            token_address, transfer.sender.starknet, transfer.recipient.starknet, transfer.amount
        );
        return _transfer_eth(token_address, transfers_len - 1, transfers + model.Transfer.SIZE);
    }
}
