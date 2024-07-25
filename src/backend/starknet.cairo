// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.memset import memset
from starkware.starknet.common.syscalls import (
    emit_event,
    get_contract_address,
    deploy as deploy_syscall,
    get_block_number,
    get_block_timestamp,
    get_tx_info,
)

from kakarot.account import Account
from kakarot.precompiles.precompiles_helpers import PrecompilesHelpers
from kakarot.constants import Constants
from kakarot.interfaces.interfaces import IERC20, IAccount

from kakarot.model import model
from kakarot.state import State
from kakarot.storages import (
    Kakarot_native_token_address,
    Kakarot_account_contract_class_hash,
    Kakarot_uninitialized_account_class_hash,
    Kakarot_evm_to_starknet_address,
    Kakarot_coinbase,
    Kakarot_base_fee,
    Kakarot_block_gas_limit,
    Kakarot_prev_randao,
)

namespace Starknet {
    // @notice Commit the current state to the underlying data backend (here, Starknet)
    // @param self The pointer to the State
    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.State*
    ) {
        alloc_locals;
        let (native_token_address) = Kakarot_native_token_address.read();

        // Accounts
        Internals._commit_accounts{state=self}(
            self.accounts_start, self.accounts, native_token_address
        );

        // Events
        Internals._emit_events(self.events_len, self.events);

        // Transfers
        Internals._transfer_eth(native_token_address, self.transfers_len, self.transfers);

        return ();
    }

    // @notice Deploy a new account
    // @dev Deploy an instance of an account
    // @param evm_address The Ethereum address which will be controlling the account
    // @return account_address The Starknet Account address
    func deploy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (account_address: felt) {
        alloc_locals;

        let (
            uninitialized_account_class_hash: felt
        ) = Kakarot_uninitialized_account_class_hash.read();
        let (constructor_calldata_len, constructor_calldata) = Account.get_constructor_calldata(
            evm_address
        );
        let (starknet_address) = deploy_syscall(
            uninitialized_account_class_hash,
            contract_address_salt=evm_address,
            constructor_calldata_size=constructor_calldata_len,
            constructor_calldata=constructor_calldata,
            deploy_from_zero=TRUE,
        );
        return (account_address=starknet_address);
    }

    // @notice Return the bytecode of a given account
    // @dev Return empty if the account is not deployed
    // @param evm_address The address of the account
    // @return bytecode_len The len of the bytecode
    // @return bytecode The bytecode
    func get_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (bytecode_len: felt, bytecode: felt*) {
        let (starknet_address) = Kakarot_evm_to_starknet_address.read(evm_address);

        if (starknet_address == 0) {
            let (bytecode: felt*) = alloc();
            return (0, bytecode);
        }

        let (bytecode_len, bytecode) = IAccount.bytecode(starknet_address);
        return (bytecode_len, bytecode);
    }

    // @notice Populate a Environment with Starknet syscalls
    func get_env{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        origin: felt, gas_price: felt
    ) -> model.Environment* {
        alloc_locals;
        let (block_number) = get_block_number();
        let (block_timestamp) = get_block_timestamp();
        let (tx_info) = get_tx_info();
        let (coinbase) = Kakarot_coinbase.read();
        let (base_fee) = Kakarot_base_fee.read();
        let (block_gas_limit) = Kakarot_block_gas_limit.read();
        let (prev_randao) = Kakarot_prev_randao.read();

        // No idea why this is required - but trying to pass prev_randao directly causes bugs.
        let prev_randao = Uint256(low=prev_randao.low, high=prev_randao.high);
        let (_, chain_id) = unsigned_div_rem(tx_info.chain_id, 2 ** 32);

        return new model.Environment(
            origin=origin,
            gas_price=gas_price,
            chain_id=chain_id,
            prev_randao=prev_randao,
            block_number=block_number,
            block_gas_limit=block_gas_limit,
            block_timestamp=block_timestamp,
            coinbase=coinbase,
            base_fee=base_fee,
        );
    }
}

namespace Internals {
    // @notice Iterate through the accounts dict and commit them
    // @dev The dicts must've been squashed before calling this function
    // @dev Account is deployed here if it doesn't exist already
    // @param accounts_start The dict start pointer
    // @param accounts_end The dict end pointer
    // @param native_token_address The address of the native token
    func _commit_accounts{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(accounts_start: DictAccess*, accounts_end: DictAccess*, native_token_address: felt) {
        alloc_locals;
        if (accounts_start == accounts_end) {
            return ();
        }

        let account = cast(accounts_start.new_value, model.Account*);
        _commit_account(account, native_token_address);

        _commit_accounts(accounts_start + DictAccess.SIZE, accounts_end, native_token_address);

        return ();
    }

    // @notice Commit the account to the storage backend at given address
    // @dev Account is deployed here if it doesn't exist already
    // @dev Works on model.Account to make sure only finalized accounts are committed.
    // @dev If the contract received funds after a selfdestruct in its creation, the funds are burnt.
    // @param self The pointer to the Account
    // @param starknet_address A starknet address to commit to
    // @param native_token_address The address of the native token
    // @notice Iterate through the storage dict and update the Starknet storage
    func _commit_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, state: model.State*
    }(self: model.Account*, native_token_address) {
        alloc_locals;

        let is_precompile = PrecompilesHelpers.is_precompile(self.address.evm);
        if (is_precompile != FALSE) {
            return ();
        }

        let starknet_account_exists = Account.is_registered(self.address.evm);
        let starknet_address = self.address.starknet;
        // Case new Account
        if (starknet_account_exists == 0) {
            // Deploy account
            Starknet.deploy(self.address.evm);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        // @dev: EIP-6780 - If selfdestruct on an account created, dont commit data
        // and burn any leftover balance.
        let is_created_selfdestructed = self.created * self.selfdestruct;
        if (is_created_selfdestructed != 0) {
            let starknet_address = Account.compute_starknet_address(Constants.BURN_ADDRESS);
            tempvar burn_address = new model.Address(
                starknet=starknet_address, evm=Constants.BURN_ADDRESS
            );
            let transfer = model.Transfer(self.address, burn_address, [self.balance]);
            State.add_transfer(transfer);
            return ();
        }

        let has_code_or_nonce = Account.has_code_or_nonce(self);
        if (has_code_or_nonce == FALSE) {
            // Nothing to commit
            return ();
        }

        // Set nonce
        IAccount.set_nonce(starknet_address, self.nonce);
        // Save storages
        Internals._save_storage(starknet_address, self.storage_start, self.storage);

        // Update bytecode and jumpdests if required (newly created account)
        if (self.created != FALSE) {
            IAccount.write_bytecode(starknet_address, self.code_len, self.code);
            Internals._save_valid_jumpdests(
                starknet_address, self.valid_jumpdests_start, self.valid_jumpdests
            );
            // Set the code hash
            IAccount.set_code_hash(starknet_address, [self.code_hash]);
            return ();
        }

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
        // See 300 max data_len for events
        // https://github.com/starkware-libs/blockifier/blob/9bfb3d4c8bf1b68a0c744d1249b32747c75a4d87/crates/blockifier/resources/versioned_constants.json
        // The whole data_len should be less than 300
        tempvar data_len = is_nn(300 - event.data_len) * (event.data_len - 300) + 300;

        emit_event(
            keys_len=event.topics_len, keys=event.topics, data_len=data_len, data=event.data
        );

        _emit_events(events_len - 1, events + model.Event.SIZE);
        return ();
    }

    // @notice Iterates through a list of Transfer and makes them
    // @dev Transfers are made last so as to have all accounts created beforehand.
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
        let value = cast(storage_start.new_value, Uint256*);
        // If the storage key has been cached as it's part of an access list,
        // the `new_value` is `0` as there has only been a read without a write,
        // thus value would be the default 0 value instead of a pointer.
        if (value == 0) {
            return _save_storage(starknet_address, storage_start + DictAccess.SIZE, storage_end);
        }

        IAccount.write_storage(
            contract_address=starknet_address, storage_addr=storage_start.key, value=[value]
        );

        return _save_storage(starknet_address, storage_start + DictAccess.SIZE, storage_end);
    }

    func _save_valid_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        starknet_address: felt, dict_start: DictAccess*, dict_end: DictAccess*
    ) {
        alloc_locals;
        let dict_len = dict_end - dict_start;
        if (dict_len == 0) {
            return ();
        }

        let (local keys_start: felt*) = alloc();

        tempvar keys = keys_start;
        tempvar dict = dict_start;
        tempvar remaining = dict_len;

        loop:
        let keys = cast([ap - 3], felt*);
        let dict = cast([ap - 2], DictAccess*);
        let is_valid = dict.new_value;

        if (is_valid != 0) {
            assert [keys] = dict.key;
            tempvar keys = keys + 1;
            tempvar dict = dict + DictAccess.SIZE;
        } else {
            tempvar keys = keys;
            tempvar dict = dict + DictAccess.SIZE;
        }
        tempvar remaining = dict_end - dict;

        static_assert keys == [ap - 3];
        static_assert dict == [ap - 2];

        jmp loop if remaining != 0;

        let keys_len = keys - keys_start;
        IAccount.write_jumpdests(starknet_address, jumpdests_len=keys_len, jumpdests=keys_start);
        return ();
    }
}
