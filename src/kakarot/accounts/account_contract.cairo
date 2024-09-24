// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable, Ownable_owner
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_le, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (
    get_tx_info,
    get_caller_address,
    get_block_timestamp,
    call_contract,
    replace_class,
)
from starkware.cairo.common.bool import FALSE, TRUE

from kakarot.accounts.library import (
    AccountContract,
    Account_authorized_message_hashes,
    Account_bytecode_len,
)
from kakarot.accounts.model import CallArray, OutsideExecution
from kakarot.interfaces.interfaces import IKakarot, IAccount
from kakarot.errors import Errors
from utils.utils import Helpers
from utils.maths import unsigned_div_rem

const GET_STARKNET_ADDRESS_SELECTOR = 0x03e5d65a345b3857ca9d72edca702b8e56c1923c118867752345f710d595b3cf;

// @title EVM smart contract account representation.
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    with_attr error_message("Accounts cannot be created directly.") {
        assert 1 = 0;
    }
    return ();
}

// @notice Initializes the account with the given EVM address.
// @param evm_address The EVM address of the account.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) {
    return AccountContract.initialize(evm_address);
}

// @notice Gets the EVM address associated with the account.
// @return address The EVM address of the account.
@view
func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return AccountContract.get_evm_address();
}

// @notice Sets the implementation of the account contract.
// @param new_class The class to replace the current implementation with.
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_class: felt) {
    // Access control check.
    Ownable.assert_only_owner();
    replace_class(new_class);
    return ();
}

// @notice Checks if the account was initialized.
// @return is_initialized 1 if the account has been initialized, 0 otherwise.
@view
func is_initialized{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (is_initialized: felt) {
    return AccountContract.is_initialized();
}

// EOA specific entrypoints

// @notice Executes a transaction from outside the account.
// @dev This function validates the transaction for account-related checks and sends it to the Kakarot contract for execution.
// Further EVM-related checks are performed in the library and in the Kakarot contract.
// @param outside_execution The outside execution context. Actually unused, but required by the SNIP-9 specification.
// @param call_array_len The length of the call array. Must be 1 as multicall is not supported.
// @param call_array An array containing the call data for the transaction.
// @param calldata_len The length of the calldata array.
// @param calldata The calldata for the transaction.
// @param signature_len The length of the signature array.
// @param signature The signature of the transaction.
// @return response_len The length of the response array.
// @return response The response from the Kakarot contract.
@external
func execute_from_outside{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(
    outside_execution: OutsideExecution,
    call_array_len: felt,
    call_array: CallArray*,
    calldata_len: felt,
    calldata: felt*,
    signature_len: felt,
    signature: felt*,
) -> (response_len: felt, response: felt*) {
    alloc_locals;
    let (caller) = get_caller_address();
    with_attr error_message("EOA: multicall not supported") {
        assert call_array_len = 1;
    }
    let (tx_info) = get_tx_info();
    let version = tx_info.version;
    with_attr error_message("Deprecated tx version: 0") {
        assert_le(1, version);
    }

    // EOA validation
    let (bytecode_len) = Account_bytecode_len.read();
    with_attr error_message("EOAs cannot have code") {
        assert bytecode_len = 0;
    }

    // Unpack the tx data
    let packed_tx_data_len = [call_array].data_len;
    with_attr error_message("Execute from outside: packed_tx_data_len is zero or out of range") {
        assert_not_zero(packed_tx_data_len);
        assert [range_check_ptr] = packed_tx_data_len;
        let range_check_ptr = range_check_ptr + 1;
    }
    let packed_tx_data = calldata + [call_array].data_offset;
    let tx_data_len = [packed_tx_data];
    with_attr error_message("Execute from outside: tx_data_len is out of range") {
        assert [range_check_ptr] = tx_data_len;
        let range_check_ptr = range_check_ptr + 1;
    }
    let (tx_data) = Helpers.load_packed_bytes(
        packed_tx_data_len - 1, packed_tx_data + 1, tx_data_len
    );

    // Get the chain id
    let (kakarot_address) = Ownable_owner.read();
    let (chain_id) = IKakarot.eth_chain_id(contract_address=kakarot_address);

    let (response_len, response) = AccountContract.execute_from_outside(
        tx_data_len, tx_data, signature_len, signature, chain_id
    );
    return (response_len, response);
}

// @notice Validate a transaction
// @dev Disabled in favor of `execute_from_outside`. Required by the Native Account Abstraction spec.
@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) {
    with_attr error_message("EOA: __validate__ not supported") {
        assert 1 = 0;
    }
    return ();
}

// @notice Disabled. Required by the Native Account Abstraction spec.
@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(class_hash: felt) {
    with_attr error_message("EOA: declare not supported") {
        assert 1 = 0;
    }
    return ();
}

// @notice Execute a starknet transaction.
// @dev Disabled in favor of `execute_from_outside`.
@external
func __execute__{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    ecdsa_ptr: SignatureBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    range_check_ptr,
}(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) -> (
    response_len: felt, response: felt*
) {
    with_attr error_message("EOA: __execute__ not supported") {
        assert 1 = 0;
    }
    let (response) = alloc();
    return (0, response);
}

// @notice Store the bytecode of the contract.
// @param bytecode_len The length of the bytecode.
// @param bytecode The bytecode of the contract.
@external
func write_bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*) {
    // Access control check.
    Ownable.assert_only_owner();
    return AccountContract.write_bytecode(bytecode_len, bytecode);
}

// @notice This function is used to get the bytecode of the smart contract.
// @return bytecode_len The bytecode array length.
// @return bytecode The bytecode of the smart contract.
@view
func bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (bytecode_len: felt, bytecode: felt*) {
    return AccountContract.bytecode();
}

// @notice This function is used to get only the bytecode_len of the smart contract.
// @dev Compared to bytecode, it does not read the code so it's much cheaper if only len is required.
// @return len The bytecode_len of the smart contract.
@view
func bytecode_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    len: felt
) {
    let (len) = AccountContract.bytecode_len();
    return (len=len);
}

// @notice Store a key-value pair.
// @param storage_addr The storage address.
// @param value The bytes32 stored value.
@external
func write_storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(storage_addr: felt, value: Uint256) {
    // Access control check.
    Ownable.assert_only_owner();
    return AccountContract.write_storage(storage_addr, value);
}

// @notice Read a given storage key
// @param storage_addr The storage address.
// @return value The stored value if the key exists, 0 otherwise.
@view
func storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(storage_addr: felt) -> (value: Uint256) {
    return AccountContract.storage(storage_addr);
}

// @notice This function is used to read the nonce from storage
// @return nonce The current nonce of the contract account
@view
func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    return AccountContract.get_nonce();
}

// @notice Sets the contract account nonce
// @param nonce The new nonce value.
@external
func set_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce: felt) {
    // Access control check.
    Ownable.assert_only_owner();
    return AccountContract.set_nonce(nonce);
}

// @notice Write valid jumpdests in the account's storage.
// @param jumpdests_len The length of the jumpdests array.
// @param jumpdests The jumpdests array, containing indexes of valid jumpdests.
@external
func write_jumpdests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    jumpdests_len: felt, jumpdests: felt*
) {
    // Access control check.
    Ownable.assert_only_owner();
    AccountContract.write_jumpdests(jumpdests_len, jumpdests);
    return ();
}

// @notice Returns whether the jumpdest at the given index is valid.
// @param index The index of the jumpdest.
// @return is_valid 1 if the jumpdest is valid, 0 otherwise.
@view
func is_valid_jumpdest{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt
) -> (is_valid: felt) {
    let is_valid = AccountContract.is_valid_jumpdest(index);
    return (is_valid=is_valid);
}

// @notice Get the code hash of the account.
// @return code_hash The code hash of the account.
@view
func get_code_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    code_hash: Uint256
) {
    let code_hash = AccountContract.get_code_hash();
    return (code_hash,);
}

// @notice Set the code hash of the account.
// @param code_hash The code hash of the account.
@external
func set_code_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    code_hash: Uint256
) {
    Ownable.assert_only_owner();
    AccountContract.set_code_hash(code_hash);
    return ();
}

// @notice Authorizes a pre-eip155 transaction by message hash.
// @param message_hash The hash of the message.
@external
func set_authorized_pre_eip155_tx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    message_hash: Uint256
) {
    // Access control check.
    Ownable.assert_only_owner();
    Account_authorized_message_hashes.write(message_hash, 1);
    return ();
}

// @notice Execute a starknet call.
// @dev Used when executing a Cairo Precompile. Used to preserve the caller address.
// Reentrancy check is done, only `get_starknet_address` is allowed for Solidity contracts
//      to be able to get the corresponding Starknet address in their calldata.
// @param to The address to call.
// @param function_selector The function selector to call.
// @param calldata_len The length of the calldata array.
// @param calldata The calldata for the call.
// @return retdata_len The length of the return data array.
// @return retdata The return data from the call.
// @return success 1 if the call was successful, 0 otherwise.
@external
func execute_starknet_call{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    to: felt, function_selector: felt, calldata_len: felt, calldata: felt*
) -> (retdata_len: felt, retdata: felt*, success: felt) {
    Ownable.assert_only_owner();
    let (kakarot_address) = Ownable.owner();
    let is_get_starknet_address = Helpers.is_zero(
        GET_STARKNET_ADDRESS_SELECTOR - function_selector
    );
    let is_kakarot = Helpers.is_zero(kakarot_address - to);
    tempvar is_forbidden = is_kakarot * (1 - is_get_starknet_address);
    if (is_forbidden != FALSE) {
        let (error_len, error) = Errors.kakarotReentrancy();
        return (error_len, error, FALSE);
    }
    let (retdata_len, retdata) = call_contract(to, function_selector, calldata_len, calldata);
    return (retdata_len, retdata, TRUE);
}
