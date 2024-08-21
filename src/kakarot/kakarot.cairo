// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import replace_class
from openzeppelin.access.ownable.library import Ownable, Ownable_owner

// Local dependencies
from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.events import kakarot_upgraded
from kakarot.library import Kakarot
from kakarot.interfaces.interfaces import IAccount
from utils.utils import Helpers

from kakarot.eth_rpc import (
    eth_get_balance,
    eth_get_transaction_count,
    eth_chain_id,
    eth_call,
    eth_estimate_gas,
    eth_send_transaction,
    eth_send_raw_transaction,
)

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    native_token_address: felt,
    account_contract_class_hash: felt,
    uninitialized_account_class_hash: felt,
    cairo1_helpers_class_hash: felt,
    coinbase: felt,
    block_gas_limit: felt,
) {
    return Kakarot.constructor(
        owner,
        native_token_address,
        account_contract_class_hash,
        uninitialized_account_class_hash,
        cairo1_helpers_class_hash,
        coinbase,
        block_gas_limit,
    );
}

// @notive Upgrade the contract
// @dev Use the replace_hash syscall to upgrade the contract
// @param new_class_hash The new class hash
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_class_hash: felt
) {
    Ownable.assert_only_owner();
    replace_class(new_class_hash);
    kakarot_upgraded.emit(new_class_hash);
    return ();
}

// @notive Returns the owner of the contract
@external
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    return Ownable_owner.read();
}

// @notive Transfer the ownership of the contract
// @param new_owner The new owner
@external
func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_owner: felt
) {
    Ownable.transfer_ownership(new_owner);
    return ();
}

// @notice Set the native token used by kakarot
// @dev Set the native token which will emulate the role of ETH on Ethereum
// @param native_token_address The address of the native token
@external
func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    native_token_address: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.set_native_token(native_token_address);
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

// @notice Set the block base fee.
// @param base_fee The new base fee.
@external
func set_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(base_fee: felt) {
    Ownable.assert_only_owner();
    return Kakarot.set_base_fee(base_fee);
}

// @notice Get the block base fee.
// @return base_fee The current block base fee.
@view
func get_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    base_fee: felt
) {
    return Kakarot.get_base_fee();
}

// @notice Set the Kakarot_coinbase.
// @param coinbase The new coinbase address.
@external
func set_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(coinbase: felt) {
    Ownable.assert_only_owner();
    return Kakarot.set_coinbase(coinbase);
}

// @notice Get the coinbase address.
// @return coinbase The coinbase address.
@view
func get_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    coinbase: felt
) {
    return Kakarot.get_coinbase();
}

// @notice Sets the prev randao
// @param prev_randao The new prev randao.
@external
func set_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_randao: Uint256
) {
    Ownable.assert_only_owner();
    return Kakarot.set_prev_randao(prev_randao);
}

// @notice Get the prev randao.
// @return prev_randao The current prev randao.
@view
func get_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    prev_randao: Uint256
) {
    return Kakarot.get_prev_randao();
}

// @notice Sets the block gas limit.
// @param gas_limit_ The new block gas limit.
@external
func set_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    gas_limit_: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.set_block_gas_limit(gas_limit_);
}

// @notice Get the block gas limit.
// @return gas_limit The current block gas limit.
@view
func get_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    block_gas_limit: felt
) {
    return Kakarot.get_block_gas_limit();
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

// @notice Return the account implementation class hash
// @return account_contract_class_hash The account implementation class hash
@view
func get_account_contract_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() -> (account_contract_class_hash: felt) {
    return Kakarot.get_account_contract_class_hash();
}

// @notice Set the account implementation class hash
// @param account_contract_class_hash The new account implementation class hash
@external
func set_account_contract_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(account_contract_class_hash: felt) {
    Ownable.assert_only_owner();
    return Kakarot.set_account_contract_class_hash(account_contract_class_hash);
}

// @notice Return the transparent account class hash
// @return uninitialized_account_class_hash The account implementation class hash
@view
func get_uninitialized_account_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() -> (uninitialized_account_class_hash: felt) {
    return Kakarot.get_uninitialized_account_class_hash();
}

// @notice Set the transparent account class hash
// @param uninitialized_account_class_hash The new account implementation class hash
@external
func set_uninitialized_account_class_hash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(uninitialized_account_class_hash: felt) {
    Ownable.assert_only_owner();
    return Kakarot.set_uninitialized_account_class_hash(uninitialized_account_class_hash);
}

// @notice Sets the authorization of an EVM address to call Cairo Precompiles
// @param evm_address The EVM address
// @param authorized Whether the EVM address is authorized or not
@external
func set_authorized_cairo_precompile_caller{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(evm_address: felt, authorized: felt) {
    Ownable.assert_only_owner();
    return Kakarot.set_authorized_cairo_precompile_caller(evm_address, authorized);
}

// @notice Set the Cairo1Helpers class hash
// @param cairo1_helpers_class_hash The Cairo1Helpers class hash
@external
func set_cairo1_helpers_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    cairo1_helpers_class_hash: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.set_cairo1_helpers_class_hash(cairo1_helpers_class_hash);
}

// @notice Return the Cairo1Helpers class hash
// @return cairo1_helpers_class_hash The Cairo1Helpers class hash
@view
func get_cairo1_helpers_class_hash{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> (cairo1_helpers_class_hash: felt) {
    return Kakarot.get_cairo1_helpers_class_hash();
}

// @notice Returns the corresponding Starknet address for a given EVM address.
// @dev Returns the registered address if there is one, otherwise returns the deterministic address got when Kakarot deploys an account.
// @param evm_address The EVM address to transform to a starknet address
// @return starknet_address The Starknet Account Contract address
@view
func get_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (starknet_address: felt) {
    let starknet_address = Account.get_starknet_address(evm_address);
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

// @notice Register the calling Starknet address for the given EVM address
// @dev    Only the corresponding computed Starknet address can make this call to ensure that registered accounts are actually deployed.
// @param evm_address The EVM address of the account.
@external
func register_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) {
    return Kakarot.register_account(evm_address);
}

// @notice Writes to an account's bytecode
// @dev Writes the bytecode to the account's storage.
// @param evm_address The evm address of the account.
// @param bytecode_len The length of the bytecode.
// @param bytecode The bytecode to write.
@external
func write_account_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt, bytecode_len: felt, bytecode: felt*
) {
    Ownable.assert_only_owner();
    return Kakarot.write_account_bytecode(evm_address, bytecode_len, bytecode);
}

// @notice Upgrades the class of an account.
// @param evm_address The evm address of the account.
// @param new_class_hash The new class hash.
@external
func upgrade_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt, new_class_hash: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.upgrade_account(evm_address, new_class_hash);
}

// @notice Writes to an account's nonce
// @dev Writes the nonce to the account's storage.
// @param evm_address The evm address of the account.
// @param nonce The nonce to write.
@external
func write_account_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt, nonce: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.write_account_nonce(evm_address, nonce);
}

@external
func set_authorized_message_sender{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender, authorized: felt
) {
    Ownable.assert_only_owner();
    return Kakarot.set_authorized_message_sender(sender, authorized);
}

@external
func set_authorized_pre_eip155_tx{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender_address: felt, msg_hash: Uint256
) {
    Ownable.assert_only_owner();
    let sender_starknet_address = Account.get_starknet_address(sender_address);
    IAccount.set_authorized_pre_eip155_tx(sender_starknet_address, msg_hash);
    return ();
}

@l1_handler
func handle_l1_message{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(from_address: felt, l1_sender: felt, to_address: felt, value: felt, data_len: felt, data: felt*) {
    alloc_locals;
    let is_authorized = Kakarot.get_authorized_message_sender(from_address);
    if (is_authorized == 0) {
        return ();
    }

    let (_, state, _, _) = Kakarot.handle_l1_message(l1_sender, to_address, value, data_len, data);

    // Reverted or not - commit the state change. If reverted, the state was cleared to only contain gas-related changes.
    Starknet.commit(state);
    return ();
}
