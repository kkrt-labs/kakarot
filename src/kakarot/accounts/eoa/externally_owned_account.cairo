// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

from kakarot.accounts.eoa.library import ExternallyOwnedAccount

// Externally Owned Account initializer
@external
func initialize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(kakarot_address: felt, evm_address: felt) {
    return ExternallyOwnedAccount.initialize(kakarot_address, evm_address);
}

// Account specific methods

// @notice validate a transaction
// @dev the transaction is considered as valid if it is signed with the correct address and is a valid kakarot transaction
// @param call_array_len The length of the call_array
// @param call_array An array containing all the calls of the transaction see: https://docs.openzeppelin.com/contracts-cairo/0.6.0/accounts#call_and_accountcallarray_format
// @param calldata_len The length of the Calldata array
// @param calldata The calldata
@external
func __validate__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(
    call_array_len: felt,
    call_array: ExternallyOwnedAccount.CallArray*,
    calldata_len: felt,
    calldata: felt*,
) {
    ExternallyOwnedAccount.validate(
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
    );
    return ();
}

// @notice validates this account class for declaration
// @dev For our use case the account doesn't need to declare contracts
@external
func __validate_declare__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(class_hash: felt) {
    assert 1 = 0;
    return ();
}

// @notice executes the Kakarot transaction
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
    call_array_len: felt,
    call_array: ExternallyOwnedAccount.CallArray*,
    calldata_len: felt,
    calldata: felt*,
) -> (response_len: felt, response: felt*) {
    return ExternallyOwnedAccount.execute(
        call_array_len=call_array_len,
        call_array=call_array,
        calldata_len=calldata_len,
        calldata=calldata,
    );
}

// @dev returns true if the interface_id is supported
// @dev TODO: check what interfaces the contract should support and maybe create one for a kakarot account
// @param interface_id The interface Id to verify if supported
@view
func supports_interface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interface_id: felt
) -> (success: felt) {
    if (interface_id == ExternallyOwnedAccount.INTERFACE_ID) {
        return (success=1);
    }
    return (success=0);
}

// @notice return ethereum address of the externally owned account
@view
func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    evm_address: felt
) {
    return ExternallyOwnedAccount.get_evm_address();
}

// @notice empty bytecode needed for EXTCODE opcodes.
@view
func bytecode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (bytecode_len: felt, bytecode: felt*) {
    let (bytecode) = alloc();
    return (0, bytecode);
}

// @notice empty bytecode needed for EXTCODE opcodes.
@view
func bytecode_len{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (len: felt) {
    return (len=0);
}
