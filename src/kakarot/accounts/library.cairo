%lang starknet

from openzeppelin.access.ownable.library import Ownable, Ownable_owner
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, split_int, split_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256, uint256_not, uint256_le
from starkware.cairo.common.math_cmp import is_nn
from starkware.starknet.common.syscalls import (
    StorageRead,
    StorageWrite,
    STORAGE_READ_SELECTOR,
    STORAGE_WRITE_SELECTOR,
    storage_read,
    storage_write,
    StorageReadRequest,
    CallContract,
    get_contract_address,
    get_caller_address,
    replace_class,
)
from starkware.cairo.common.memset import memset

from kakarot.interfaces.interfaces import IERC20, IKakarot, ICairo1Helpers
from kakarot.accounts.model import CallArray
from kakarot.errors import Errors
from kakarot.constants import Constants
from utils.eth_transaction import EthTransaction
from utils.uint256 import uint256_add
from utils.bytes import bytes_to_bytes8_little_endian
from utils.signature import Signature
from utils.utils import Helpers

// @dev: should always be zero for EOAs
@storage_var
func Account_bytecode_len() -> (res: felt) {
}

@storage_var
func Account_storage(key: Uint256) -> (value: Uint256) {
}

@storage_var
func Account_is_initialized() -> (res: felt) {
}

@storage_var
func Account_nonce() -> (nonce: felt) {
}

@storage_var
func Account_implementation() -> (address: felt) {
}

@storage_var
func Account_evm_address() -> (evm_address: felt) {
}

@storage_var
func Account_valid_jumpdests() -> (is_valid: felt) {
}

@storage_var
func Account_jumpdests_initialized() -> (initialized: felt) {
}

@storage_var
func Account_authorized_message_hashes(hash: Uint256) -> (res: felt) {
}

@event
func transaction_executed(response_len: felt, response: felt*, success: felt, gas_used: felt) {
}

const BYTES_PER_FELT = 31;

// @title Account main library file.
// @notice This file contains the EVM account representation logic.
// @dev: Both EOAs and Contract Accounts are represented by this contract.
namespace AccountContract {
    // 000.001.000
    const VERSION = 000001000;

    // @notice This function is used to initialize the smart contract account.
    // @dev The `evm_address` and `kakarot_address` were set during the uninitialized_account creation.
    // Reading them from state ensures that they always match the ones the account was created for.
    func initialize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(kakarot_address, evm_address, implementation_class) {
        alloc_locals;
        let (is_initialized) = Account_is_initialized.read();
        with_attr error_message("Account already initialized") {
            assert is_initialized = 0;
        }
        Account_is_initialized.write(1);
        Ownable.initializer(kakarot_address);
        Account_evm_address.write(evm_address);
        Account_implementation.write(implementation_class);

        // Give infinite ETH transfer allowance to Kakarot
        let (native_token_address) = IKakarot.get_native_token(kakarot_address);
        let infinite = Uint256(Constants.UINT128_MAX, Constants.UINT128_MAX);
        IERC20.approve(native_token_address, kakarot_address, infinite);

        // Register the account in the Kakarot mapping
        IKakarot.register_account(kakarot_address, evm_address);
        return ();
    }

    func get_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        implementation: felt
    ) {
        let (implementation) = Account_implementation.read();
        return (implementation=implementation);
    }

    func set_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_implementation: felt
    ) {
        replace_class(new_implementation);
        Account_implementation.write(new_implementation);
        return ();
    }

    // @return address The EVM address of the account
    func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        address: felt
    ) {
        let (address) = Account_evm_address.read();
        return (address=address);
    }

    // @notice This function checks if the account was initialized.
    // @return is_initialized 1 if the account has been initialized 0 otherwise.
    func is_initialized{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (is_initialized: felt) {
        let is_initialized: felt = Account_is_initialized.read();
        return (is_initialized=is_initialized);
    }

    // EOA functions

    // @notice Validate an Ethereum transaction and execute it.
    // @dev This function validates the transaction by checking its signature,
    // chain_id, nonce and gas. It then sends it to Kakarot.
    // @param tx_data_len The length of tx data
    // @param tx_data The tx data.
    // @param signature_len The length of tx signature.
    // @param signature The tx signature.
    // @param chain_id The expected chain id of the tx
    func execute_from_outside{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(tx_data_len: felt, tx_data: felt*, signature_len: felt, signature: felt*, chain_id: felt) -> (
        response_len: felt, response: felt*
    ) {
        alloc_locals;

        with_attr error_message("Incorrect signature length") {
            assert signature_len = 5;
        }
        let r = Uint256(signature[0], signature[1]);
        let s = Uint256(signature[2], signature[3]);
        let v = signature[4];

        let tx_type = EthTransaction.get_tx_type(tx_data);
        local y_parity: felt;
        local pre_eip155_tx: felt;
        if (tx_type == 0) {
            let is_eip155_tx = is_nn(28 - v);
            assert pre_eip155_tx = is_eip155_tx;
            if (is_eip155_tx != FALSE) {
                assert y_parity = v - 27;
            } else {
                assert y_parity = (v - 2 * chain_id - 35);
            }
            tempvar range_check_ptr = range_check_ptr;
        } else {
            assert pre_eip155_tx = FALSE;
            assert y_parity = v;
            tempvar range_check_ptr = range_check_ptr;
        }
        let range_check_ptr = [ap - 1];

        let (local words: felt*) = alloc();
        let (words_len, last_word, last_word_num_bytes) = bytes_to_bytes8_little_endian(
            words, tx_data_len, tx_data
        );
        let (kakarot_address) = Ownable_owner.read();
        let (helpers_class) = IKakarot.get_cairo1_helpers_class_hash(kakarot_address);
        let (msg_hash) = ICairo1Helpers.library_call_keccak(
            class_hash=helpers_class,
            words_len=words_len,
            words=words,
            last_input_word=last_word,
            last_input_num_bytes=last_word_num_bytes,
        );
        let (address) = Account_evm_address.read();
        Signature.verify_eth_signature_uint256(
            msg_hash=msg_hash,
            r=r,
            s=s,
            v=y_parity,
            eth_address=address,
            helpers_class=helpers_class,
        );

        let tx = EthTransaction.decode(tx_data_len, tx_data);

        // Whitelisting pre-eip155 or validate chain_id for post eip155
        if (pre_eip155_tx != FALSE) {
            let (is_authorized) = Account_authorized_message_hashes.read(msg_hash);
            with_attr error_message("Unauthorized pre-eip155 transaction") {
                assert is_authorized = TRUE;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            with_attr error_message("Invalid chain id") {
                assert tx.chain_id = chain_id;
            }
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        let syscall_ptr = cast([ap - 3], felt*);
        let pedersen_ptr = cast([ap - 2], HashBuiltin*);
        let range_check_ptr = [ap - 1];

        // Validate nonce
        let (account_nonce) = Account_nonce.read();
        with_attr error_message("Invalid nonce") {
            assert tx.signer_nonce = account_nonce;
        }

        // Validate gas and value
        let (kakarot_address) = Ownable_owner.read();
        let (native_token_address) = IKakarot.get_native_token(kakarot_address);
        let (contract_address) = get_contract_address();
        let (balance) = IERC20.balanceOf(native_token_address, contract_address);

        let max_gas_fee = tx.gas_limit * tx.max_fee_per_gas;
        let (max_fee_high, max_fee_low) = split_felt(max_gas_fee);
        let (tx_cost, carry) = uint256_add(tx.amount, Uint256(low=max_fee_low, high=max_fee_high));
        assert carry = 0;
        let (is_balance_enough) = uint256_le(tx_cost, balance);
        with_attr error_message("Not enough ETH to pay msg.value + max gas fees") {
            assert is_balance_enough = TRUE;
        }

        let (block_gas_limit) = IKakarot.get_block_gas_limit(kakarot_address);
        let tx_gas_fits_in_block = is_nn(block_gas_limit - tx.gas_limit);
        with_attr error_message("Transaction gas_limit > Block gas_limit") {
            assert tx_gas_fits_in_block = TRUE;
        }

        let (block_base_fee) = IKakarot.get_base_fee(kakarot_address);
        let enough_fee = is_nn(tx.max_fee_per_gas - block_base_fee);
        with_attr error_message("Max fee per gas too low") {
            assert enough_fee = TRUE;
        }

        let max_fee_greater_priority_fee = is_nn(tx.max_fee_per_gas - tx.max_priority_fee_per_gas);
        with_attr error_message("Max priority fee greater than max fee per gas") {
            assert max_fee_greater_priority_fee = TRUE;
        }

        let possible_priority_fee = tx.max_fee_per_gas - block_base_fee;
        let priority_fee_is_max_priority_fee = is_nn(
            possible_priority_fee - tx.max_priority_fee_per_gas
        );
        let priority_fee_per_gas = priority_fee_is_max_priority_fee * tx.max_priority_fee_per_gas +
            (1 - priority_fee_is_max_priority_fee) * possible_priority_fee;
        let effective_gas_price = priority_fee_per_gas + block_base_fee;

        // Send tx to Kakarot
        let (return_data_len, return_data, success, gas_used) = IKakarot.eth_send_transaction(
            contract_address=kakarot_address,
            to=tx.destination,
            gas_limit=tx.gas_limit,
            gas_price=effective_gas_price,
            value=tx.amount,
            data_len=tx.payload_len,
            data=tx.payload,
            access_list_len=tx.access_list_len,
            access_list=tx.access_list,
        );

        // See Argent account
        // https://github.com/argentlabs/argent-contracts-starknet/blob/c6d3ee5e05f0f4b8a5c707b4094446c3bc822427/contracts/account/ArgentAccount.cairo#L132
        // See 300 max data_len for events
        // https://github.com/starkware-libs/blockifier/blob/9bfb3d4c8bf1b68a0c744d1249b32747c75a4d87/crates/blockifier/resources/versioned_constants.json
        // The whole data_len should be less than 300, so it's the return_data should be less than 297 (+3 for return_data_len, success, gas_used)
        tempvar return_data_len = is_nn(297 - return_data_len) * (return_data_len - 297) + 297;
        transaction_executed.emit(
            response_len=return_data_len, response=return_data, success=success, gas_used=gas_used
        );

        return (response_len=return_data_len, response=return_data);
    }

    // Contract Account functions

    // @notice Store the bytecode of the contract.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        // Recursively store the bytecode.
        Account_bytecode_len.write(bytecode_len);
        Internals.write_bytecode(bytecode_len=bytecode_len, bytecode=bytecode);
        return ();
    }

    // @notice This function is used to get the bytecode_len of the smart contract.
    // @return bytecode_len The length of the bytecode.
    func bytecode_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        res: felt
    ) {
        return Account_bytecode_len.read();
    }

    // @notice This function is used to get the bytecode of the smart contract.
    // @return bytecode_len The length of the bytecode.
    // @return bytecode The bytecode of the smart contract.
    func bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() -> (bytecode_len: felt, bytecode: felt*) {
        alloc_locals;
        let (bytecode_len) = Account_bytecode_len.read();
        let (bytecode_) = Internals.load_bytecode(bytecode_len);
        return (bytecode_len, bytecode_);
    }

    // @notice This function is used to read the storage at a key.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @return value The store value.
    func storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt) -> (value: Uint256) {
        let (low) = storage_read(address=storage_addr + 0);
        let (high) = storage_read(address=storage_addr + 1);
        let value = Uint256(low, high);
        return (value,);
    }

    // @notice This function is used to write to the storage of the account.
    // @param key The storage key, which is hash_felts(cast(Uint256, felt*)) of the Uint256 storage key.
    // @param value The value to store.
    func write_storage{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(storage_addr: felt, value: Uint256) {
        // Write State
        storage_write(address=storage_addr + 0, value=value.low);
        storage_write(address=storage_addr + 1, value=value.high);
        return ();
    }

    // @notice This function is used to read the nonce from storage
    // @dev If the nonce is that of an EOA and the previous transaction reverted with a CairoVM,
    // the nonce was not incremented and this is off-by-one until the next successful CairoVM execution.
    // @return nonce The current nonce of the contract account
    func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        nonce: felt
    ) {
        return Account_nonce.read();
    }

    // @notice This function set the account nonce
    func set_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        new_nonce: felt
    ) {
        Account_nonce.write(new_nonce);
        return ();
    }

    // @notice Return the latest available implementation of the account contract.
    // @returns The latest account class hash registered in Kakarot
    func get_latest_classes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        account_class: felt, cairo1_helpers_class: felt
    ) {
        let (kakarot_address) = Ownable_owner.read();
        let (latest_account_class) = IKakarot.get_account_contract_class_hash(kakarot_address);
        let (latest_cairo1_helpers_class) = IKakarot.get_cairo1_helpers_class_hash(kakarot_address);
        return (latest_account_class, latest_cairo1_helpers_class);
    }

    // @notice Writes an array of valid jumpdests indexes to storage.
    // @param jumpdests_len The length of the jumpdests array.
    // @param jumpdests The jumpdests array.
    func write_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        jumpdests_len: felt, jumpdests: felt*
    ) {
        // Recursively store the jumpdests.
        Internals.write_jumpdests(
            jumpdests_len=jumpdests_len, jumpdests=jumpdests, iteration_size=1
        );
        return ();
    }

    func is_valid_jumpdest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index: felt
    ) -> felt {
        alloc_locals;
        let (base_address) = Account_valid_jumpdests.addr();
        let index_address = base_address + index;

        let syscall = [cast(syscall_ptr, StorageRead*)];
        assert syscall.request = StorageReadRequest(
            selector=STORAGE_READ_SELECTOR, address=index_address
        );
        %{ syscall_handler.storage_read(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        let response = syscall.response;
        tempvar syscall_ptr = syscall_ptr + StorageRead.SIZE;
        tempvar value = response.value;

        if (value != 0) {
            return value;
        }

        // Jumpdest is invalid - we verify that the jumpdests have been stored, and if not,
        // we store them. call the appropriate function check & store
        let (initialized) = Account_jumpdests_initialized.read();

        if (initialized != FALSE) {
            return value;
        }

        let (bytecode_len) = Account_bytecode_len.read();
        let (bytecode) = Internals.load_bytecode(bytecode_len);
        let (valid_jumpdests_start, valid_jumpdests) = Helpers.initialize_jumpdests(
            bytecode_len, bytecode
        );
        let (jumpdests_len, _) = unsigned_div_rem(
            valid_jumpdests - valid_jumpdests_start, DictAccess.SIZE
        );
        Internals.write_jumpdests(
            jumpdests_len=jumpdests_len,
            jumpdests=cast(valid_jumpdests_start, felt*),
            iteration_size=DictAccess.SIZE,
        );
        return is_valid_jumpdest(index=index);
    }
}

namespace Internals {
    // @notice asserts that the caller is the account itself
    func assert_only_self{syscall_ptr: felt*}() {
        let (this) = get_contract_address();
        let (caller) = get_caller_address();
        with_attr error_message("Only the account itself can call this function") {
            assert caller = this;
        }
        return ();
    }

    // @notice Store the bytecode of the contract.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func write_bytecode{syscall_ptr: felt*}(bytecode_len: felt, bytecode: felt*) {
        alloc_locals;

        if (bytecode_len == 0) {
            return ();
        }

        tempvar value = 0;
        tempvar address = 0;
        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len;
        tempvar count = BYTES_PER_FELT;

        body:
        let value = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let bytecode_len = [ap - 2];
        let count = [ap - 1];
        let initial_bytecode_len = [fp - 4];
        let bytecode = cast([fp - 3], felt*);

        tempvar value = value * 256 + bytecode[initial_bytecode_len - bytecode_len];
        tempvar address = address;
        tempvar syscall_ptr = syscall_ptr;
        tempvar bytecode_len = bytecode_len - 1;
        tempvar count = count - 1;

        jmp cond if bytecode_len != 0;
        jmp store;

        cond:
        jmp body if count != 0;

        store:
        assert [cast(syscall_ptr, StorageWrite*)] = StorageWrite(
            selector=STORAGE_WRITE_SELECTOR, address=address, value=value
        );
        %{ syscall_handler.storage_write(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        tempvar value = 0;
        tempvar address = address + 1;
        tempvar syscall_ptr = syscall_ptr + StorageWrite.SIZE;
        tempvar bytecode_len = bytecode_len;
        tempvar count = BYTES_PER_FELT;

        jmp body if bytecode_len != 0;

        return ();
    }

    // @notice Store the jumpdests of the contract.
    // @dev This function can be used by either passing an array of valid jumpdests,
    // or a dict that only contains valid entries (i.e. no invalid index has been read).
    // @param jumpdests_len The length of the valid jumpdests.
    // @param jumpdests The jumpdests of the contract. Can be an array of valid indexes or a dict.
    // @param iteration_size The size of the object we are iterating over.
    func write_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        jumpdests_len: felt, jumpdests: felt*, iteration_size: felt
    ) {
        alloc_locals;

        if (jumpdests_len == 0) {
            return ();
        }

        let (local base_address) = Account_valid_jumpdests.addr();
        local pedersen_ptr: HashBuiltin* = pedersen_ptr;
        local range_check_ptr = range_check_ptr;
        tempvar syscall_ptr = syscall_ptr;
        tempvar jumpdests = jumpdests;
        tempvar remaining = jumpdests_len;

        body:
        let syscall_ptr = cast([ap - 3], felt*);
        let jumpdests = cast([ap - 2], felt*);
        let remaining = [ap - 1];
        let base_address = [fp];
        let iteration_size = [fp - 3];

        let index_to_store = [jumpdests];
        tempvar storage_address = base_address + index_to_store;

        assert [cast(syscall_ptr, StorageWrite*)] = StorageWrite(
            selector=STORAGE_WRITE_SELECTOR, address=storage_address, value=1
        );
        %{ syscall_handler.storage_write(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        tempvar syscall_ptr = syscall_ptr + StorageWrite.SIZE;
        tempvar jumpdests = jumpdests + iteration_size;
        tempvar remaining = remaining - 1;

        jmp body if remaining != 0;

        Account_jumpdests_initialized.write(1);
        return ();
    }

    // @notice Load the bytecode of the contract in the specified array.
    // @param index The index in the bytecode.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode of the contract.
    func load_bytecode{syscall_ptr: felt*, range_check_ptr}(bytecode_len: felt) -> (
        bytecode: felt*
    ) {
        alloc_locals;

        let (local bytecode: felt*) = alloc();
        local bound = 256;
        local base = 256;

        if (bytecode_len == 0) {
            return (bytecode=bytecode);
        }

        let (local chunk_counts, local remainder) = unsigned_div_rem(bytecode_len, BYTES_PER_FELT);

        tempvar remaining_bytes = bytecode_len;
        tempvar range_check_ptr = range_check_ptr;
        tempvar address = 0;
        tempvar syscall_ptr = syscall_ptr;
        tempvar value = 0;
        tempvar count = 0;

        read:
        let remaining_bytes = [ap - 6];
        let range_check_ptr = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let value = [ap - 2];
        let count = [ap - 1];

        let syscall = [cast(syscall_ptr, StorageRead*)];
        assert syscall.request = StorageReadRequest(
            selector=STORAGE_READ_SELECTOR, address=address
        );
        %{ syscall_handler.storage_read(segments=segments, syscall_ptr=ids.syscall_ptr) %}
        let response = syscall.response;

        let remainder = [fp + 4];
        let chunk_counts = [fp + 3];
        tempvar remaining_chunk = chunk_counts - address;
        jmp full_chunk if remaining_chunk != 0;
        tempvar count = remainder;
        jmp next;

        full_chunk:
        tempvar count = BYTES_PER_FELT;

        next:
        tempvar remaining_bytes = remaining_bytes;
        tempvar range_check_ptr = range_check_ptr;
        tempvar address = address + 1;
        tempvar syscall_ptr = syscall_ptr + StorageRead.SIZE;
        tempvar value = response.value;
        tempvar count = count;

        body:
        let remaining_bytes = [ap - 6];
        let range_check_ptr = [ap - 5];
        let address = [ap - 4];
        let syscall_ptr = cast([ap - 3], felt*);
        let value = [ap - 2];
        let count = [ap - 1];

        let base = [fp + 1];
        let bound = [fp + 2];
        let bytecode = cast([fp], felt*);
        tempvar offset = (address - 1) * BYTES_PER_FELT + count - 1;
        let output = bytecode + offset;

        // Put byte in output and assert that 0 <= byte < bound
        // See math.split_int
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar a = [output];
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr];
        tempvar a = bound - 1 - a;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr + 1];

        tempvar value = (value - [output]) / base;
        tempvar remaining_bytes = remaining_bytes - 1;
        tempvar range_check_ptr = range_check_ptr + 2;
        tempvar address = address;
        tempvar syscall_ptr = syscall_ptr;
        tempvar value = value;
        tempvar count = count - 1;

        jmp cond if remaining_bytes != 0;

        let bytecode = cast([fp], felt*);
        return (bytecode=bytecode);

        cond:
        jmp body if count != 0;
        jmp read;
    }
}
