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

namespace State {
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
        let self = finalize(self);
        let (local events: felt*) = alloc();
        memcpy(dst=events, src=self.events, len=self.events_len * model.Event.SIZE);
        let (local transfers: felt*) = alloc();
        memcpy(dst=transfers, src=self.transfers, len=self.transfers_len * model.Transfer.SIZE);
        return new model.State(
            accounts_start=self.accounts_start,
            accounts=self.accounts,
            events_len=self.events_len,
            events=cast(events, model.Event*),
            balances_start=self.balances_start,
            balances=self.balances,
            transfers_len=self.transfers_len,
            transfers=cast(transfers, model.Transfer*),
        );
    }

    // @dev Squash dicts used internally
    // @param self The pointer to the State
    func finalize{range_check_ptr}(self: model.State*) -> model.State* {
        alloc_locals;
        let (local accounts_start, accounts) = default_dict_finalize(
            self.accounts_start, self.accounts, 0
        );
        Internals._finalize_accounts{accounts=accounts}(accounts_start, accounts);

        let (balances_start, balances) = default_dict_finalize(
            self.balances_start, self.balances, 0
        );

        return new model.State(
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
    // @param self The pointer to the State
    func commit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.State*) {
        // Accounts
        Internals._save_accounts(self.accounts_start, self.accounts);

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
        let (pointer) = dict_read{dict_ptr=accounts}(key=address.evm);

        if (pointer != 0) {
            // Return from local storage if found
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
            let (bytecode_len, bytecode) = Accounts.get_bytecode(address.evm);
            // we assume that if there is no bytecode this is an EOA.
            // in this context, the nonce is managed by Starkware and not accessible from within
            // the contract, hence we put 0.
            // It shouldn't have any impact
            if (bytecode_len == 0) {
                let account = new_account(code_len=bytecode_len, code=bytecode, nonce=0);
                dict_write{dict_ptr=accounts}(key=address.evm, new_value=cast(account, felt));
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

            let (nonce) = IContractAccount.get_nonce(contract_address=address.starknet);
            let account = new_account(code_len=bytecode_len, code=bytecode, nonce=nonce);
            dict_write{dict_ptr=accounts}(key=address.evm, new_value=cast(account, felt));
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

    // @notice Create a new account
    // @dev New accounts start at nonce=1.
    // @param code_len The length of the code
    // @param code The pointer to the code
    // @param nonce The initial nonce
    // @return The updated state
    // @return The account
    func new_account(code_len: felt, code: felt*, nonce: felt) -> model.Account* {
        let (storage_start) = default_dict_new(0);
        return new model.Account(
            code_len=code_len,
            code=code,
            storage_start=storage_start,
            storage=storage_start,
            nonce=nonce,
        );
    }

    // @notice Set the Account at the given address
    // @param self The pointer to the State.
    // @param address The address of the Account
    // @param account The new account
    func set_account(
        self: model.State*, address: model.Address*, account: model.Account*
    ) -> model.State* {
        let accounts = self.accounts;
        dict_write{dict_ptr=accounts}(key=address.evm, new_value=cast(account, felt));
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
    }(self: model.State*, address: model.Address*, key: Uint256*) -> (model.State*, Uint256) {
        alloc_locals;
        let (self, account) = get_account(self, address);
        let storage = account.storage;
        let (local storage_key) = hash_felts{hash_ptr=pedersen_ptr}(cast(key, felt*), 2);

        let (pointer) = dict_read{dict_ptr=storage}(key=storage_key);

        if (pointer != 0) {
            // Return from local storage if found
            let value_ptr = cast(pointer, Uint256*);
            tempvar account = new model.Account(
                account.code_len, account.code, account.storage_start, storage, account.nonce
            );
            let self = set_account(self, address, account);

            return (self, [value_ptr]);
        } else {
            // Otherwise regular read value from contract storage
            let (value) = IContractAccount.storage(contract_address=address.starknet, key=[key]);
            // Cache for possible later use (almost free and can save a lot)
            tempvar new_value = new Uint256(value.low, value.high);
            dict_write{dict_ptr=storage}(key=storage_key, new_value=cast(new_value, felt));
            tempvar account = new model.Account(
                account.code_len, account.code, account.storage_start, storage, account.nonce
            );
            let self = set_account(self, address, account);
            return (self, value);
        }
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
        local storage: DictAccess* = account.storage;
        let (storage_key) = hash_felts{hash_ptr=pedersen_ptr}(cast(key, felt*), 2);
        dict_write{dict_ptr=storage}(key=storage_key, new_value=cast(value, felt));
        tempvar account = new model.Account(
            account.code_len, account.code, account.storage_start, storage, account.nonce
        );
        let self = set_account(self, address, account);
        return self;
    }

    // @notice Add an event to the Event* array
    // @param self The pointer to the State
    // @param event The pointer to the Event
    // @return The updated State
    func add_event(self: model.State*, event: model.Event*) -> model.State* {
        assert [self.events + self.events_len] = [event];
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
    func add_transfer{range_check_ptr}(
        self: model.State*, transfer: model.Transfer*
    ) -> model.State* {
        alloc_locals;
        // See https://docs.cairo-lang.org/0.12.0/how_cairo_works/functions.html#retrieving-registers
        let fp_and_pc = get_fp_and_pc();
        local __fp__: felt* = fp_and_pc.fp_val;

        let balances = self.balances;

        let (local pointer) = dict_read{dict_ptr=balances}(transfer.sender.evm);
        tempvar sender_balance_prev_ptr = cast(pointer, Uint256*);
        tempvar sender_balance_prev = Uint256(
            sender_balance_prev_ptr.low, sender_balance_prev_ptr.high
        );

        let (local pointer) = dict_read{dict_ptr=balances}(transfer.recipient.evm);
        tempvar recipient_balance_prev_ptr = cast(pointer, Uint256*);
        tempvar recipient_balance_prev = Uint256(
            recipient_balance_prev_ptr.low, recipient_balance_prev_ptr.high
        );

        let (local sender_balance_new) = uint256_sub(sender_balance_prev, transfer.amount);
        tempvar sender_balance_new_ptr = new Uint256(
            sender_balance_new.low, sender_balance_new.high
        );
        let (local recipient_balance_new, carry) = uint256_add(
            recipient_balance_prev, transfer.amount
        );
        tempvar recipient_balance_new_ptr = new Uint256(
            recipient_balance_new.low, recipient_balance_new.high
        );

        dict_write{dict_ptr=balances}(
            key=transfer.sender.evm, new_value=cast(&sender_balance_new, felt)
        );
        dict_write{dict_ptr=balances}(
            key=transfer.recipient.evm, new_value=cast(&recipient_balance_new, felt)
        );
        assert [self.transfers + self.transfers_len] = [transfer];

        return new model.State(
            accounts_start=self.accounts_start,
            accounts=self.accounts,
            events_len=self.events_len,
            events=self.events,
            balances_start=self.balances_start,
            balances=balances,
            transfers_len=self.transfers_len + 1,
            transfers=self.transfers,
        );
    }

    // @notice Get the balance of a given address
    // @dev Try to read from local dict, and read from ETH contract otherwise
    // @param self The pointer to the State
    // @param address The pointer to the Address
    func read_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(self: model.State*, address: model.Address*) -> (state: model.State*, balance: Uint256) {
        let balances = self.balances;
        let (pointer) = dict_read{dict_ptr=balances}(key=address.evm);
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
            dict_write{dict_ptr=balances}(key=address.evm, new_value=cast(balance_ptr, felt));
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
    // @notice Iterate through the accounts dict and finalize them
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _finalize_accounts{range_check_ptr, accounts: DictAccess*}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        if (accounts_start == accounts_end) {
            return ();
        }

        let address = cast(accounts_start.key, model.Address*);
        let account = cast(accounts_start.new_value, model.Account*);

        let storage = account.storage;
        let (storage_start, storage) = default_dict_finalize(
            account.storage_start, account.storage, 0
        );
        tempvar account = new model.Account(
            code_len=account.code_len,
            code=account.code,
            storage_start=storage_start,
            storage=storage,
            nonce=account.nonce,
        );
        dict_write{dict_ptr=accounts}(key=accounts_start.key, new_value=cast(account, felt));

        return _finalize_accounts(accounts_start + DictAccess.SIZE, accounts_end);
    }

    // @notice Iterate through the accounts dict and update the Starknet storage
    // @dev Account is deployed here if it doesn't exist already
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    func _save_accounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        accounts_start: DictAccess*, accounts_end: DictAccess*
    ) {
        alloc_locals;
        if (accounts_start == accounts_end) {
            return ();
        }

        let address = cast(accounts_start.key, model.Address*);
        let account = cast(accounts_start.new_value, model.Account*);

        IContractAccount.set_nonce(address.starknet, account.nonce);
        _save_storage(address, account.storage_start, account.storage);

        let (bytecode_len) = Accounts.get_bytecode_len(address.starknet);
        if (bytecode_len != 0) {
            // Account bytecode is immutable, so if a bytecode is already here, it must
            // be the same
            _save_accounts(accounts_start + DictAccess.SIZE, accounts_end);
            return ();
        }

        // Deploy accounts
        let (class_hash) = contract_account_class_hash.read();
        Accounts.create(class_hash, address.evm);
        // Write bytecode
        IContractAccount.write_bytecode(address.starknet, account.code_len, account.code);
        _save_accounts(accounts_start + DictAccess.SIZE, accounts_end);

        return ();
    }

    // @notice Iterates through the storage dict and update Contract Account storage.
    // @param storage_start The dict start pointer
    // @param storage_end The dict end pointer
    func _save_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: model.Address*, storage_start: DictAccess*, storage_end: DictAccess*
    ) {
        if (storage_start == storage_end) {
            return ();
        }
        let key = cast(storage_start.key, Uint256*);
        let value = cast(storage_start.new_value, Uint256*);

        IContractAccount.write_storage(contract_address=address.starknet, key=[key], value=[value]);

        return _save_storage(address, storage_start + DictAccess.SIZE, storage_end);
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
