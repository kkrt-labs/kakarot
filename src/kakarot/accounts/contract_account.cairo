// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.accounts.library import GenericAccount
from starkware.starknet.common.syscalls import get_tx_info, get_caller_address
from starkware.cairo.common.math import assert_le, unsigned_div_rem
from starkware.cairo.common.alloc import alloc

// @title EVM smart contract account representation.

// @notice Initializes the account with the given Kakarot and EVM addresses.
// @param kakarot_address The address of the main Kakarot contract.
// @param evm_address The EVM address of the account.
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, evm_address: felt) {
    return GenericAccount.initialize(kakarot_address, evm_address);
}

// @notice replaces the class of the account.
// @param new_class The new class of the account.
@external
func upgrade{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(new_class: felt) {
    return GenericAccount.upgrade(new_class);
}

// @notice Gets the evm address associated with the account.
// @return address The EVM address of the account.
@view
func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return GenericAccount.get_evm_address();
}

// @notice Checks if the account was initialized.
// @return is_initialized: 1 if the account has been initialized 0 otherwise.
@view
func is_initialized{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (is_initialized: felt) {
    return GenericAccount.is_initialized();
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
}(
    call_array_len: felt, call_array: GenericAccount.CallArray*, calldata_len: felt, calldata: felt*
) {
    GenericAccount.validate(
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
}(
    call_array_len: felt, call_array: GenericAccount.CallArray*, calldata_len: felt, calldata: felt*
) -> (response_len: felt, response: felt*) {
    alloc_locals;
    let (tx_info) = get_tx_info();
    let version = tx_info.version;
    with_attr error_message("EOA: deprecated tx version: {version}") {
        assert_le(1, version);
    }

    let (caller) = get_caller_address();
    with_attr error_message("EOA: reentrant call") {
        assert caller = 0;
    }

    let (local response: felt*) = alloc();
    let (response_len) = GenericAccount.execute(
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
        response=response,
    );
    return (response_len, response);
}

// @dev Return true if the interface_id is supported
// @dev TODO: check what interfaces the contract should support and maybe create one for a kakarot account
// @param interface_id The interface Id to verify if supported
@view
func supports_interface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interface_id: felt
) -> (success: felt) {
    if (interface_id == GenericAccount.INTERFACE_ID) {
        return (success=1);
    }
    return (success=0);
}

// @notice Store the bytecode of the contract.
// @param bytecode The bytecode of the contract.
// @param bytecode_len The length of the bytecode.
@external
func write_bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*) {
    return GenericAccount.write_bytecode(bytecode_len, bytecode);
}

// @notice This function is used to get the bytecode of the smart contract.
// @return bytecode_len The bytecode array length.
// @return bytecode The bytecode of the smart contract.
@view
func bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (bytecode_len: felt, bytecode: felt*) {
    return GenericAccount.bytecode();
}

// @notice This function is used to get only the bytecode_len of the smart contract.
// @dev Compared to bytecode, it does not read the code so it's much cheaper if only len is required.
// @return len The bytecode_len of the smart contract.
@view
func bytecode_len{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (len: felt) {
    let (len) = GenericAccount.bytecode_len();
    return (len=len);
}

// @notice Store a key-value pair.
// @param key The storage address, with storage_var being storage_(key: Uint256)
// @param value The bytes32 stored value.
@external
func write_storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(storage_addr: felt, value: Uint256) {
    return GenericAccount.write_storage(storage_addr, value);
}

// @notice Read a given storage key
// @param key The storage address, with storage_var being storage_(key: Uint256)
// @return value The stored value if the key exists, 0 otherwise.
@view
func storage{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(storage_addr: felt) -> (value: Uint256) {
    return GenericAccount.storage(storage_addr);
}

// @notice This function is used to read the nonce from storage
// @return nonce The current nonce of the contract account
@view
func get_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (nonce: felt) {
    return GenericAccount.get_nonce();
}

// @notice This function set the contract account nonce
@external
func set_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(nonce: felt) {
    return GenericAccount.set_nonce(nonce);
}
