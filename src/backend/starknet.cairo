// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256
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
from kakarot.constants import Constants
from kakarot.events import evm_contract_deployed
from kakarot.interfaces.interfaces import IERC20, IContractAccount, IAccount
from kakarot.model import model
from kakarot.state import State
from kakarot.storages import (
    native_token_address,
    contract_account_class_hash,
    account_proxy_class_hash,
    evm_to_starknet_address,
)

namespace Starknet {
    // @notice Commit the current state to the underlying data backend (here, Starknet)
    // @param self The pointer to the State
    func commit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.State*
    ) {
        // Accounts
        Internals._commit_accounts(self.accounts_start, self.accounts);

        // Events
        Internals._emit_events(self.events_len, self.events);

        // Transfers
        let (native_token_address_) = native_token_address.read();
        Internals._transfer_eth(native_token_address_, self.transfers_len, self.transfers);

        return ();
    }

    // @notice Deploy a new account proxy
    // @dev Deploy an instance of an account
    // @param evm_address The Ethereum address which will be controlling the account
    // @param class_hash The hash of the implemented account (eoa/contract)
    // @return account_address The Starknet Account Proxy address
    func deploy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_hash: felt, evm_address: felt
    ) -> (account_address: felt) {
        alloc_locals;
        let (kakarot_address: felt) = get_contract_address();
        let (_account_proxy_class_hash: felt) = account_proxy_class_hash.read();
        let (constructor_calldata: felt*) = alloc();
        let (starknet_address) = deploy_syscall(
            _account_proxy_class_hash,
            contract_address_salt=evm_address,
            constructor_calldata_size=0,
            constructor_calldata=constructor_calldata,
            deploy_from_zero=0,
        );
        assert constructor_calldata[0] = kakarot_address;
        assert constructor_calldata[1] = evm_address;
        IAccount.initialize(starknet_address, class_hash, 2, constructor_calldata);
        evm_contract_deployed.emit(evm_address, starknet_address);
        evm_to_starknet_address.write(evm_address, starknet_address);
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
        let (starknet_address) = evm_to_starknet_address.read(evm_address);

        if (starknet_address == 0) {
            let (bytecode: felt*) = alloc();
            return (0, bytecode);
        }

        let (bytecode_len, bytecode) = IAccount.bytecode(starknet_address);
        return (bytecode_len, bytecode);
    }

    // @notice Populate a Environment with Starknet syscalls
    func get_env{syscall_ptr: felt*}(origin: felt, gas_price: felt) -> model.Environment* {
        alloc_locals;
        let (block_number) = get_block_number();
        let (block_timestamp) = get_block_timestamp();
        let (tx_info) = get_tx_info();
        let (block_hashes) = alloc();
        // TODO: fix how blockhashes are retrieved
        memset(block_hashes, 0, 256 * 2);

        let coinbase = Uint256(
            0xacdffe0cf08e20ed8ba10ea97a487004, 0x388ca486b82e20cc81965d056b4cdca
        );
        return new model.Environment(
            origin=origin,
            gas_price=gas_price,
            chain_id=tx_info.chain_id,
            prev_randao=Uint256(0, 0),
            block_number=block_number,
            block_gas_limit=Constants.BLOCK_GAS_LIMIT,
            block_timestamp=block_timestamp,
            block_hashes=cast(block_hashes, Uint256*),
            coinbase=coinbase,
        );
    }
}

namespace Internals {
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

        let account = cast(accounts_start.new_value, model.Account*);
        _commit_account(account);

        _commit_accounts(accounts_start + DictAccess.SIZE, accounts_end);

        return ();
    }

    // @notice Commit the account to the storage backend at given address
    // @dev Account is deployed here if it doesn't exist already
    // @dev Works on model.Account to make sure only finalized accounts are committed.
    // @param self The pointer to the Account
    // @param starknet_address A starknet address to commit to
    // @notice Iterate through the storage dict and update the Starknet storage
    func _commit_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*
    ) {
        alloc_locals;

        let starknet_account_exists = Account.is_registered(self.address.evm);
        let starknet_address = self.address.starknet;
        // Case new Account
        if (starknet_account_exists == 0) {
            // Just casting the Summary into an Account to apply has_code_or_nonce
            // cf Summary note: like an Account, but frozen after squashing all dicts
            // There is no reason to have has_code_or_nonce available in the public API
            // for model.Account, but safe to use here
            let code_or_nonce = Account.has_code_or_nonce(self);

            if (code_or_nonce != FALSE) {
                // Deploy accounts
                let (class_hash) = contract_account_class_hash.read();
                Starknet.deploy(class_hash, self.address.evm);
                // If SELFDESTRUCT, stops here to leave the account empty
                if (self.selfdestruct != 0) {
                    return ();
                }

                // Write bytecode
                IContractAccount.write_bytecode(starknet_address, self.code_len, self.code);
                // Set nonce
                IContractAccount.set_nonce(starknet_address, self.nonce);
                // Save storages
                _save_storage(starknet_address, self.storage_start, self.storage);
                return ();
            } else {
                // Touched an undeployed address in a CALL, do nothing
                return ();
            }
        }

        // Case existing Account and SELFDESTRUCT
        if (self.selfdestruct != 0) {
            IContractAccount.selfdestruct(contract_address=starknet_address);
            return ();
        }

        let (account_type) = IAccount.account_type(contract_address=starknet_address);
        if (account_type == 'EOA') {
            return ();
        }

        // Set nonce
        IContractAccount.set_nonce(starknet_address, self.nonce);
        // Save storages
        Internals._save_storage(starknet_address, self.storage_start, self.storage);

        // Update bytecode if required (SELFDESTRUCTed contract, redeployed)
        let (bytecode_len) = IAccount.bytecode_len(starknet_address);
        if (bytecode_len != self.code_len) {
            IContractAccount.write_bytecode(starknet_address, self.code_len, self.code);
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
        emit_event(
            keys_len=event.topics_len, keys=event.topics, data_len=event.data_len, data=event.data
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

        IContractAccount.write_storage(
            contract_address=starknet_address, storage_addr=storage_start.key, value=[value]
        );

        return _save_storage(starknet_address, storage_start + DictAccess.SIZE, storage_end);
    }
}
