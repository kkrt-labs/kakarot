// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.registers import get_fp_and_pc

// Local dependencies
from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.library import Kakarot
from utils.utils import Helpers

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    native_token_address_: felt,
    contract_account_class_hash_: felt,
    externally_owned_account_class_hash: felt,
    account_proxy_class_hash: felt,
    deploy_fee: felt,
    precompiles_class_hash: felt,
) {
    return Kakarot.constructor(
        owner,
        native_token_address_,
        contract_account_class_hash_,
        externally_owned_account_class_hash,
        account_proxy_class_hash,
        deploy_fee,
        precompiles_class_hash,
    );
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
    let starknet_address = Account.compute_starknet_address(evm_address);
    return (contract_address=starknet_address);
}

// @notice Returns the registered starknet address for a given EVM address.
// @dev Returns 0 if no contract is deployed for this EVM address.
// @param evm_address The EVM address to transform to a starknet address
// @return starknet_address The Starknet Account Contract address or 0 if not already deployed
@view
func get_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (starknet_address: felt) {
    let starknet_address = Account.get_registered_starknet_address(evm_address);
    return (starknet_address=starknet_address);
}

// @notice Deploy a new externally owned account.
// @param evm_address The evm address that is mapped to the newly deployed starknet contract address.
// @return starknet_contract_address The newly deployed starknet contract address.
@external
func deploy_externally_owned_account{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(evm_address: felt) -> (starknet_contract_address: felt) {
    return Kakarot.deploy_externally_owned_account(evm_address);
}

// @notice The eth_call function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
//         This is a view only function, meaning that it doesn't make any state change.
// @param origin The address the transaction is sent from.
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return gas_used The amount of gas used by the transaction
@view
func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    origin: felt,
    to: felt,
    gas_limit: felt,
    gas_price: felt,
    value: Uint256,
    data_len: felt,
    data: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    let (evm, state) = Kakarot.eth_call(origin, to, gas_limit, gas_price, &value, data_len, data);
    let gas_used = gas_limit - evm.gas_left;
    return (evm.return_data_len, evm.return_data, 1 - evm.reverted, gas_used);
}

// @notice The eth_send_transaction function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction
// @dev "nonce" parameter is taken from the corresponding account contract
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return gas_used The amount of gas used by the transaction
@external
func eth_send_transaction{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(to: felt, gas_limit: felt, gas_price: felt, value: Uint256, data_len: felt, data: felt*) -> (
    return_data_len: felt, return_data: felt*, success: felt, gas_used: felt
) {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    let (local starknet_caller_address) = get_caller_address();
    let (local origin) = Kakarot.safe_get_evm_address(starknet_caller_address);
    let (evm, state) = Kakarot.eth_call(origin, to, gas_limit, gas_price, &value, data_len, data);
    let gas_used = gas_limit - evm.gas_left;
    let result = (evm.return_data_len, evm.return_data, 1 - evm.reverted, gas_used);

    if (evm.reverted != FALSE) {
        return result;
    }

    Starknet.commit(state);

    return result;
}
