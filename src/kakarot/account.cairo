// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.storage import normalize_address
from starkware.starknet.common.syscalls import deploy as deploy_syscall, get_contract_address
from starkware.cairo.common.hash_state import (
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash_update_with_hashchain,
)

from kakarot.constants import (
    Constants,
    account_proxy_class_hash,
    native_token_address,
    contract_account_class_hash,
)
from kakarot.interfaces.interfaces import IAccount, IContractAccount
from kakarot.model import model
from utils.dict import default_dict_copy
from utils.utils import Helpers

@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

@storage_var
func evm_to_starknet_address(evm_address: felt) -> (starknet_address: felt) {
}

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

        let (registered_starknet_account) = get_registered_starknet_address(self.address);
        let starknet_account_exists = is_not_zero(registered_starknet_account);

        // Case new Account
        if (starknet_account_exists == 0) {
            // If SELFDESTRUCT, just do nothing
            if (self.selfdestruct != 0) {
                return ();
            }

            // Deploy accounts
            let (class_hash) = contract_account_class_hash.read();
            deploy(class_hash, self.address);
            // Write bytecode
            IContractAccount.write_bytecode(starknet_address, self.code_len, self.code);
            // Set nonce
            IContractAccount.set_nonce(starknet_address, self.nonce);
            // Save storages
            Internals._save_storage(starknet_address, self.storage_start, self.storage);
            return ();
        }

        // Case existing Account and SELFDESTRUCT
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

        // Case EOA
        // TODO: use supports interface instead of the bytecode_len proxy
        let (bytecode_len) = IAccount.bytecode_len(contract_address=starknet_address);
        if (bytecode_len == 0) {
            return ();
        }

        // Set nonce
        IContractAccount.set_nonce(starknet_address, self.nonce);
        // Save storages
        Internals._save_storage(starknet_address, self.storage_start, self.storage);

        return ();
    }

    // @notice fetch an account from Starknet
    // @dev An non-deployed account is just an empty account.
    // @param address the pointer to the Address
    // @return the account populated with Starknet data
    func fetch_or_create{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: model.Address*
    ) -> model.Account* {
        alloc_locals;
        let (local registered_starknet_account) = get_registered_starknet_address(address.evm);
        let starknet_account_exists = is_not_zero(registered_starknet_account);

        // Case touching a non deployed account
        if (starknet_account_exists == 0) {
            let (bytecode: felt*) = alloc();
            let account = Account.init(address=address.evm, code_len=0, code=bytecode, nonce=0);
            return account;
        }

        // Case EOA
        // TODO: use supports interface instead of the bytecode_len proxy
        let (bytecode_len, bytecode) = IAccount.bytecode(contract_address=address.starknet);
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
        self: model.Account*, address: model.Address*, key: Uint256
    ) -> (model.Account*, Uint256) {
        alloc_locals;
        let storage = self.storage;
        let (local storage_addr) = Internals._storage_addr(key);
        let (pointer) = dict_read{dict_ptr=storage}(key=storage_addr);

        // Case reading from local storage
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
        }

        // Case reading from Starknet storage
        let (local registered_starknet_account) = get_registered_starknet_address(address.evm);
        let starknet_account_exists = is_not_zero(registered_starknet_account);
        if (starknet_account_exists != 0) {
            let (value) = IContractAccount.storage(
                contract_address=address.starknet, storage_addr=storage_addr
            );
            tempvar value_ptr = new Uint256(value.low, value.high);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            // Otherwise returns 0
        } else {
            tempvar value_ptr = new Uint256(0, 0);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }

        // Cache for possible later use (almost free and can save a syscall later on)
        dict_write{dict_ptr=storage}(key=storage_addr, new_value=cast(value_ptr, felt));

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
    }

    // @notice Update a storage key with the given value
    // @param self The pointer to the Account.
    // @param key The pointer to the Uint256 storage key
    // @param value The pointer to the Uint256 value
    func write_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, key: Uint256, value: Uint256*
    ) -> model.Account* {
        alloc_locals;
        local storage: DictAccess* = self.storage;
        let (storage_addr) = Internals._storage_addr(key);
        dict_write{dict_ptr=storage}(key=storage_addr, new_value=cast(value, felt));
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

    // @notice Set the nonce of the Account
    // @param self The pointer to the Account
    // @param nonce The new nonce
    func set_nonce(self: model.Account*, nonce: felt) -> model.Account* {
        return new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=self.storage,
            nonce=nonce,
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

    // @dev Returns the registered starknet address for a given EVM address. Returns 0 if no contract is deployed for this
    //      EVM address.
    // @param evm_address The EVM address to transform to a starknet address
    // @return starknet_address The Starknet Account Contract address or 0 if not already deployed
    func get_registered_starknet_address{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_address: felt) -> (starknet_address: felt) {
        return evm_to_starknet_address.read(evm_address);
    }

    // @dev As contract addresses are deterministic we can know what will be the address of a starknet contract from its input EVM address
    // @dev Adapted code from: https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo
    // @param evm_address The EVM address to transform to a starknet address
    // @return contract_address The Starknet Account Contract address (not necessarily deployed)
    func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (contract_address: felt) {
        alloc_locals;
        let (_deployer_address: felt) = get_contract_address();
        let (_account_proxy_class_hash: felt) = account_proxy_class_hash.read();
        let (constructor_calldata: felt*) = alloc();
        let (hash_state_ptr) = hash_init();
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=Constants.CONTRACT_ADDRESS_PREFIX
        );
        // hash deployer
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=_deployer_address
        );
        // hash salt
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=evm_address
        );
        // hash class hash
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=_account_proxy_class_hash
        );
        let (hash_state_ptr) = hash_update_with_hashchain{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, data_ptr=constructor_calldata, data_length=0
        );
        let (contract_address_before_modulo) = hash_finalize{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr
        );
        let (contract_address) = normalize_address{range_check_ptr=range_check_ptr}(
            addr=contract_address_before_modulo
        );

        return (contract_address=contract_address);
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

    // @notice Tells if an account has code_len > 0 or nonce > 0
    // @dev See https://github.com/ethereum/execution-specs/blob/3fe6514f2d9d234e760d11af883a47c1263eff51/src/ethereum/shanghai/state.py#L352
    // @param self The pointer to the Account
    // @return TRUE is either nonce > 0 or code_len > 0, FALSE otherwise
    func has_code_or_nonce(self: model.Account*) -> felt {
        if (self.nonce + self.code_len != 0) {
            return TRUE;
        }
        return FALSE;
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
        let value = cast(storage_start.new_value, Uint256*);

        IContractAccount.write_storage(
            contract_address=starknet_address, storage_addr=storage_start.key, value=[value]
        );

        return _save_storage(starknet_address, storage_start + DictAccess.SIZE, storage_end);
    }

    // @notice Compute the storage address of the given key when the storage var interface is
    //         storage_(key: Uint256)
    // @dev    Just the generated addr method when compiling the contract_account
    func _storage_addr{pedersen_ptr: HashBuiltin*, range_check_ptr}(key: Uint256) -> (res: felt) {
        let res = 1510236440068827666686527023008568026372765124888307403567795291192307314167;
        let (res) = hash2{hash_ptr=pedersen_ptr}(res, cast(&key, felt*)[0]);
        let (res) = hash2{hash_ptr=pedersen_ptr}(res, cast(&key, felt*)[1]);
        let (res) = normalize_address(addr=res);
        return (res=res);
    }
}
