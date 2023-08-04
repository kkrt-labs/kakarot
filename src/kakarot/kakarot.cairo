// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc

// Local dependencies
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.accounts.library import Accounts

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    native_token_address_: felt,
    contract_account_class_hash_,
    externally_owned_account_class_hash,
    account_proxy_class_hash,
    deploy_fee,
) {
    return Kakarot.constructor(
        owner,
        native_token_address_,
        contract_account_class_hash_,
        externally_owned_account_class_hash,
        account_proxy_class_hash,
        deploy_fee,
    );
}

// @notice Set the blockhash registry used by kakarot.
// @dev Set the blockhash registry which will be used to get the blockhashes.
// @param blockhash_registry_address_ The address of the new blockhash registry contract.
@external
func set_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    blockhash_registry_address_: felt
) {
    return Kakarot.set_blockhash_registry(blockhash_registry_address_);
}

// @notice Get the blockhash registry used by kakarot.
// @return address The address of the current blockhash registry contract.
@view
func get_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    return Kakarot.get_blockhash_registry();
}

// @notice Set the native token used by kakarot
// @dev Set the native token which will emulate the role of ETH on Ethereum
// @param native_token_address_ The address of the native token
@external
func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address_: felt
) {
    return Kakarot.set_native_token(native_token_address_);
}

// @notice Get the native token address
// @dev Return the address used to emulate the role of ETH on Ethereum
// @return native_token_address The address of the native token
@view
func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    native_token_address: felt
) {
    return Kakarot.get_native_token();
}

// @notice Set the deploy fee for deploying EOA on Kakarot.
// @dev Set the deploy fee to be returned to a deployer for deploying accounts.
// @param deploy_fee_ The new deploy fee.
@external
func set_deploy_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    deploy_fee_: felt
) {
    return Kakarot.set_deploy_fee(deploy_fee_);
}

// @notice Get the deploy fee for deploying EOA on Kakarot.
// @dev Return the deploy fee which is returned to a deployer for deploying accounts.
// @return deploy_fee The deploy fee which is returned to a deployer for deploying accounts.
@view
func get_deploy_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    deploy_fee: felt
) {
    return Kakarot.get_deploy_fee();
}

// @notice Compute the starknet address of a contract given its EVM address
// @param evm_address The EVM address of the contract
// @return contract_address The starknet address of the contract
@view
func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (contract_address: felt) {
    return Accounts.compute_starknet_address(evm_address);
}

// @notice Deploy a new externally owned account.
// @param evm_address The evm address that is mapped to the newly deployed starknet contract address.
// @return starknet_contract_address The newly deployed starknet contract address.
@external
func deploy_externally_owned_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) -> (starknet_contract_address: felt) {
    return Kakarot.deploy_externally_owned_account(evm_address);
}

// @notice The eth_call function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
//         This is a view only function, meaning that it doesn't make any state change.
// @dev "from" parameter is taken from get_caller_address syscall
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
@view
func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*
) {
    return Kakarot.eth_call(to, gas_limit, gas_price, value, data_len, data);
}

// @notice The eth_send_transaction function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction
// @dev "from" parameter is taken from get_caller_address syscall
// @dev "nonce" parameter is taken from the corresponding account contract
// @dev "from" parameter is taken from get_caller_address syscall
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
@external
func eth_send_transaction{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*
) {
    return Kakarot.eth_send_transaction(to, gas_limit, gas_price, value, data_len, data);
}
