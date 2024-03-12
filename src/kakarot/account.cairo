// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash_update_with_hashchain,
)
from starkware.starknet.common.storage import normalize_address
from starkware.starknet.common.syscalls import get_contract_address

from kakarot.constants import Constants
from kakarot.storages import (
    account_proxy_class_hash,
    native_token_address,
    contract_account_class_hash,
)
from kakarot.interfaces.interfaces import IAccount, IContractAccount, IERC20
from kakarot.model import model
from kakarot.storages import evm_to_starknet_address
from utils.dict import default_dict_copy
from utils.utils import Helpers

namespace Account {
    // @notice Create a new account
    // @dev New contract accounts start at nonce=1.
    // @param address The address (starknet,evm) of the account
    // @param code_len The length of the code
    // @param code The pointer to the code
    // @param nonce The initial nonce
    // @return The updated state
    // @return The account
    func init(
        address: model.Address*, code_len: felt, code: felt*, nonce: felt, balance: Uint256*
    ) -> model.Account* {
        let (storage_start) = default_dict_new(0);
        let (transient_storage_start) = default_dict_new(0);
        return new model.Account(
            address=address,
            code_len=code_len,
            code=code,
            storage_start=storage_start,
            storage=storage_start,
            transient_storage_start=transient_storage_start,
            transient_storage=transient_storage_start,
            nonce=nonce,
            balance=balance,
            selfdestruct=0,
        );
    }

    // @dev Copy the Account to safely mutate the storage
    // @dev Squash dicts used internally
    // @param self The pointer to the Account
    func copy{range_check_ptr}(self: model.Account*) -> model.Account* {
        alloc_locals;
        let (storage_start, storage) = default_dict_copy(self.storage_start, self.storage);
        let (transient_storage_start, transient_storage) = default_dict_copy(
            self.transient_storage_start, self.transient_storage
        );
        return new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=storage_start,
            storage=storage,
            transient_storage_start=transient_storage_start,
            transient_storage=transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
        );
    }

    // @notice fetch an account from Starknet
    // @dev An non-deployed account is just an empty account.
    // @param address the EVM address of the account
    // @return the account populated with Starknet data
    func fetch_or_create{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> model.Account* {
        alloc_locals;
        let starknet_address = get_registered_starknet_address(evm_address);

        local balance_ptr: Uint256*;

        // Case touching a non deployed account
        if (starknet_address == 0) {
            let (bytecode: felt*) = alloc();
            let starknet_address = compute_starknet_address(evm_address);
            tempvar address = new model.Address(starknet=starknet_address, evm=evm_address);
            let balance = fetch_balance(address);
            assert balance_ptr = new Uint256(balance.low, balance.high);
            let account = Account.init(
                address=address, code_len=0, code=bytecode, nonce=0, balance=balance_ptr
            );
            return account;
        } else {
            tempvar address = new model.Address(starknet=starknet_address, evm=evm_address);
            let balance = fetch_balance(address);
            assert balance_ptr = new Uint256(balance.low, balance.high);
        }

        let (account_type) = IAccount.account_type(contract_address=starknet_address);

        if (account_type == 'EOA') {
            let (bytecode: felt*) = alloc();
            // There is no way to access the nonce of an EOA currently
            // But putting 1 shouldn't have any impact and is safer than 0
            // since has_code_or_nonce is used in some places to trigger collision
            let account = Account.init(
                address=address, code_len=0, code=bytecode, nonce=1, balance=balance_ptr
            );
            return account;
        }

        // Case CA
        let (bytecode_len, bytecode) = IAccount.bytecode(contract_address=starknet_address);
        let (nonce) = IContractAccount.get_nonce(contract_address=starknet_address);
        let account = Account.init(
            address, code_len=bytecode_len, code=bytecode, nonce=nonce, balance=balance_ptr
        );
        return account;
    }

    // @notice Read a given storage
    // @dev Try to retrieve in the local Dict<Uint256*> first, if not already here
    //      read the contract storage and cache the result.
    // @param self The pointer to the execution Account.
    // @param key The pointer to the storage key
    // @return The updated Account
    // @return The read value
    func read_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, key: Uint256*
    ) -> (model.Account*, Uint256*) {
        alloc_locals;
        let storage = self.storage;
        let (local storage_addr) = Internals._storage_addr(key);
        let (pointer) = dict_read{dict_ptr=storage}(key=storage_addr);

        // Case reading from local storage
        if (pointer != 0) {
            // Return from local storage if found
            let value_ptr = cast(pointer, Uint256*);
            tempvar self = new model.Account(
                address=self.address,
                code_len=self.code_len,
                code=self.code,
                storage_start=self.storage_start,
                storage=storage,
                transient_storage_start=self.transient_storage_start,
                transient_storage=self.transient_storage,
                nonce=self.nonce,
                balance=self.balance,
                selfdestruct=self.selfdestruct,
            );
            return (self, value_ptr);
        }

        // Case reading from Starknet storage
        let starknet_account_exists = is_registered(self.address.evm);
        if (starknet_account_exists != 0) {
            let (value) = IContractAccount.storage(
                contract_address=self.address.starknet, storage_addr=storage_addr
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
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=storage,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
        );
        return (self, value_ptr);
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
        let (storage_addr) = Internals._storage_addr(key);
        dict_write{dict_ptr=storage}(key=storage_addr, new_value=cast(value, felt));
        tempvar self = new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=storage,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
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
        return new model.Account(
            address=self.address,
            code_len=code_len,
            code=code,
            storage_start=self.storage_start,
            storage=self.storage,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
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
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
        );
    }

    // @notice Fetches the balance of an account without loading the Account
    // @param address The address of the account
    // @return the Uint256 balance
    func fetch_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        address: model.Address*
    ) -> Uint256 {
        let (native_token_address_) = native_token_address.read();
        let (balance) = IERC20.balanceOf(native_token_address_, address.starknet);
        return balance;
    }

    // @notice Fetches the storage of an account without loading the Account
    // @dev The value is fetched from the Starknet state, and not from the local state
    // in which it might have been modified.
    // @param account The account to fetch the storage from
    // @param key The pointer to the Uint256 storage key
    // @return The Uint256 value of the original storage.
    func fetch_original_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        account: model.Account*, key: Uint256*
    ) -> Uint256 {
        alloc_locals;
        let starknet_account_exists = is_registered(account.address.evm);
        if (starknet_account_exists == FALSE) {
            let value = Uint256(0, 0);
            return value;
        }
        let (storage_addr) = Internals._storage_addr(key);
        let (value) = IContractAccount.storage(
            contract_address=account.address.starknet, storage_addr=storage_addr
        );
        return value;
    }

    // @notice Set the balance of the Account
    // @param self The pointer to the Account
    // @param balance The new balance
    func set_balance(self: model.Account*, balance: Uint256*) -> model.Account* {
        return new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=self.storage,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=balance,
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
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=1,
        );
    }

    // @dev Returns the registered starknet address for a given EVM address. Returns 0 if no contract is deployed for this
    //      EVM address.
    // @param evm_address The EVM address to transform to a starknet address
    // @return starknet_address The Starknet Account Contract address or 0 if not already deployed
    func get_registered_starknet_address{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_address: felt) -> felt {
        let (starknet_address) = evm_to_starknet_address.read(evm_address);
        return starknet_address;
    }

    // @dev As contract addresses are deterministic we can know what will be the address of a starknet contract from its input EVM address
    // @dev Adapted code from: https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo
    // @param evm_address The EVM address to transform to a starknet address
    // @return contract_address The Starknet Account Contract address (not necessarily deployed)
    func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> felt {
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

        return contract_address;
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

    // @notice Tell if an account is already registered
    // @param evm_address the address (EVM) as felt
    // @return true if the account is already registered
    func is_registered{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> felt {
        alloc_locals;
        let registered_starknet_account = get_registered_starknet_address(evm_address);
        let starknet_account_exists = is_not_zero(registered_starknet_account);
        return starknet_account_exists;
    }

    // @notice Initializes a dictionary of valid jump destinations in EVM bytecode.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The EVM bytecode to analyze.
    // @return (valid_jumpdests_start, valid_jumpdests) The starting and ending pointers of the valid jump destinations.
    //
    // @dev This function iterates over the bytecode from the current index 'i'.
    // If the opcode at the current index is between 0x5f and 0x7f (PUSHN opcodes) (inclusive),
    // it skips the next 'n_args' opcodes, where 'n_args' is the opcode minus 0x5f.
    // If the opcode is 0x5b (JUMPDEST), it marks the current index as a valid jump destination.
    // It continues by jumping back to the body flag until it has processed the entire bytecode.
    func get_jumpdests{range_check_ptr}(bytecode_len: felt, bytecode: felt*) -> (
        valid_jumpdests_start: DictAccess*, valid_jumpdests: DictAccess*
    ) {
        alloc_locals;
        let (local valid_jumpdests_start: DictAccess*) = default_dict_new(0);
        tempvar range_check_ptr = range_check_ptr;
        tempvar valid_jumpdests = valid_jumpdests_start;
        tempvar i = 0;
        jmp body if bytecode_len != 0;

        static_assert range_check_ptr == [ap - 3];
        jmp end;

        body:
        let bytecode_len = [fp - 4];
        let bytecode = cast([fp - 3], felt*);
        let range_check_ptr = [ap - 3];
        let valid_jumpdests = cast([ap - 2], DictAccess*);
        let i = [ap - 1];

        tempvar opcode = [bytecode + i];
        let is_opcode_ge_0x5f = is_le(0x5f, opcode);
        let is_opcode_le_0x7f = is_le(opcode, 0x7f);
        let is_push_opcode = is_opcode_ge_0x5f * is_opcode_le_0x7f;
        let next_i = i + 1 + is_push_opcode * (opcode - 0x5f);  // 0x5f is the first PUSHN opcode, opcode - 0x5f is the number of arguments.

        if (opcode == 0x5b) {
            dict_write{dict_ptr=valid_jumpdests}(i, TRUE);
            tempvar valid_jumpdests = valid_jumpdests;
            tempvar next_i = next_i;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar valid_jumpdests = valid_jumpdests;
            tempvar next_i = next_i;
            tempvar range_check_ptr = range_check_ptr;
        }

        tempvar is_not_done = is_le(next_i + 1, bytecode_len);
        tempvar range_check_ptr = range_check_ptr;
        tempvar valid_jumpdests = valid_jumpdests;
        tempvar i = next_i;
        static_assert range_check_ptr == [ap - 3];
        static_assert valid_jumpdests == [ap - 2];
        static_assert i == [ap - 1];
        jmp body if is_not_done != 0;

        end:
        tempvar range_check_ptr = [ap - 3];
        return (valid_jumpdests_start, valid_jumpdests);
    }

    func is_storage_warm{pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, key: Uint256*
    ) -> (model.Account*, felt) {
        alloc_locals;
        local storage: DictAccess* = self.storage;
        let (local storage_addr) = Internals._storage_addr(key);
        let (pointer) = dict_read{dict_ptr=storage}(key=storage_addr);

        tempvar account = new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=storage,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
        );

        if (pointer != 0) {
            return (account, TRUE);
        }
        return (account, FALSE);
    }

    // @notice Caches the given storage keys by creating an entry in the storage dict of the account.
    // @dev This is used for access list transactions that provide a list of preaccessed keys
    // @param storage_keys_len The number of storage keys to cache.
    // @param storage_keys The pointer to the first storage key.
    func cache_storage_keys{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        self: model.Account*, storage_keys_len: felt, storage_keys: Uint256*
    ) -> model.Account* {
        alloc_locals;
        let storage_ptr = self.storage;
        with storage_ptr {
            Internals._cache_storage_keys(self.address.evm, storage_keys_len, storage_keys);
        }
        tempvar self = new model.Account(
            address=self.address,
            code_len=self.code_len,
            code=self.code,
            storage_start=self.storage_start,
            storage=storage_ptr,
            transient_storage_start=self.transient_storage_start,
            transient_storage=self.transient_storage,
            nonce=self.nonce,
            balance=self.balance,
            selfdestruct=self.selfdestruct,
        );
        return self;
    }
}

namespace Internals {
    // @notice Compute the storage address of the given key when the storage var interface is
    //         storage_(key: Uint256)
    // @dev    Just the generated addr method when compiling the contract_account
    func _storage_addr{pedersen_ptr: HashBuiltin*, range_check_ptr}(key: Uint256*) -> (res: felt) {
        let res = 1510236440068827666686527023008568026372765124888307403567795291192307314167;
        let (res) = hash2{hash_ptr=pedersen_ptr}(res, cast(key, felt*)[0]);
        let (res) = hash2{hash_ptr=pedersen_ptr}(res, cast(key, felt*)[1]);
        let (res) = normalize_address(addr=res);
        return (res=res);
    }

    func _cache_storage_keys{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, storage_ptr: DictAccess*
    }(evm_address: felt, storage_keys_len: felt, storage_keys: Uint256*) {
        alloc_locals;
        if (storage_keys_len == 0) {
            return ();
        }

        let key = storage_keys;
        let (local storage_addr) = Internals._storage_addr(key);
        // Cache value read from Starknet storage

        let starknet_address = Account.get_registered_starknet_address(evm_address);
        if (starknet_address != 0) {
            let (value) = IContractAccount.storage(
                contract_address=starknet_address, storage_addr=storage_addr
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
        dict_write{dict_ptr=storage_ptr}(key=storage_addr, new_value=cast(value_ptr, felt));

        return _cache_storage_keys(evm_address, storage_keys_len - 1, storage_keys + Uint256.SIZE);
    }
}
