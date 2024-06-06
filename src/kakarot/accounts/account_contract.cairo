// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from openzeppelin.access.ownable.library import Ownable, Ownable_owner
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.accounts.library import (
    AccountContract,
    Account_implementation,
    Account_cairo1_helpers_class_hash,
)
from kakarot.accounts.model import CallArray
from kakarot.interfaces.interfaces import IKakarot, IAccount
from starkware.starknet.common.syscalls import get_tx_info, get_caller_address, replace_class
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.alloc import alloc

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

// @notice Initializes the account with the given Kakarot and EVM addresses.
// @param kakarot_address The address of the main Kakarot contract.
// @param evm_address The EVM address of the account.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, evm_address: felt, implementation_class: felt) {
    return AccountContract.initialize(kakarot_address, evm_address, implementation_class);
}

// @notice Returns the version of the account class.
// @dev The version is a packed integer with the following format: XXX.YYY.ZZZ where XXX is the
// major version, YYY is the minor version and ZZZ is the patch version.
@view
func version{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (version: felt) {
    let version = AccountContract.VERSION;
    return (version=version);
}

// @notice Gets the evm address associated with the account.
// @return address The EVM address of the account.
@view
func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return AccountContract.get_evm_address();
}

@view
func get_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    implementation: felt
) {
    return AccountContract.get_implementation();
}

@external
func set_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    implementation_class: felt
) {
    // Access control check.
    Ownable.assert_only_owner();
    return AccountContract.set_implementation(implementation_class);
}

// @notice Checks if the account was initialized.
// @return is_initialized: 1 if the account has been initialized 0 otherwise.
@view
func is_initialized{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (is_initialized: felt) {
    return AccountContract.is_initialized();
}

// EOA specific entrypoints

// @notice Validate a transaction
// @dev The transaction is considered as valid if it is signed with the correct address and is a valid kakarot transaction
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata
@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) {
    AccountContract.validate(
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
    );
    return ();
}

// @notice Validate this account class for declaration
// @dev For our use case the account doesn't need to declare contracts
// @param class_hash The account class
@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(class_hash: felt) {
    with_attr error_message("EOA: declare not supported") {
        assert 1 = 0;
    }
    return ();
}

// @notice Execute the Kakarot transaction
// @dev this is executed only if the __validate__ function succeeded
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata
// @return response_len The length of the response array
// @return response The response from the kakarot contract
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
    alloc_locals;

    // Upgrade flow
    let (latest_account_class, latest_helpers_class) = AccountContract.get_latest_classes();
    let (this_helpers_class) = Account_cairo1_helpers_class_hash.read();
    if (latest_helpers_class != this_helpers_class) {
        Account_cairo1_helpers_class_hash.write(latest_helpers_class);
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    }
    let syscall_ptr = cast([ap - 3], felt*);
    let range_check_ptr = [ap - 2];
    let pedersen_ptr = cast([ap - 1], HashBuiltin*);

    let (this_class) = Account_implementation.read();
    if (latest_account_class != this_class) {
        Account_implementation.write(latest_account_class);
        // Library call to new class
        let (response_len, response) = IAccount.library_call___execute__(
            class_hash=latest_account_class,
            call_array_len=call_array_len,
            call_array=call_array,
            calldata_len=calldata_len,
            calldata=calldata,
        );
        replace_class(latest_account_class);
        return (response_len, response);
    }

    // Execution flow
    let (tx_info) = get_tx_info();
    let version = tx_info.version;
    with_attr error_message("EOA: deprecated tx version: {version}") {
        assert_le(1, version);
    }

    let (caller) = get_caller_address();
    with_attr error_message("EOA: reentrant call") {
        assert caller = 0;
    }

    with_attr error_message("EOA: multicall not supported") {
        assert call_array_len = 1;
    }

    let (local response: felt*) = alloc();
    let (response_len) = AccountContract.execute(
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
        response=response,
    );
    return (response_len, response);
}

// @notice Store the bytecode of the contract.
// @param bytecode The bytecode of the contract.
// @param bytecode_len The length of the bytecode.
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
// @param key The storage address, with storage_var being Account_storage(key: Uint256)
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
// @param key The storage address, with storage_var being Account_storage(key: Uint256)
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

// @notice This function set the contract account nonce
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
