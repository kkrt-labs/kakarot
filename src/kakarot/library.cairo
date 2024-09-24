// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import split_felt

from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.storages import (
    Kakarot_uninitialized_account_class_hash,
    Kakarot_account_contract_class_hash,
    Kakarot_base_fee,
    Kakarot_native_token_address,
    Kakarot_cairo1_helpers_class_hash,
    Kakarot_coinbase,
    Kakarot_prev_randao,
    Kakarot_block_gas_limit,
    Kakarot_evm_to_starknet_address,
    Kakarot_authorized_cairo_precompiles_callers,
    Kakarot_l1_messaging_contract_address,
)
from kakarot.events import evm_contract_deployed
from kakarot.interpreter import Interpreter
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.model import model
from utils.maths import unsigned_div_rem

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
namespace Kakarot {
    // @notice The constructor of the contract.
    // @dev Set up the initial owner, accounts class hash and native token.
    // @param owner The address of the owner of the contract.
    // @param native_token_address The ERC20 contract used to emulate ETH.
    // @param account_contract_class_hash The clash hash of the contract account.
    // @param uninitialized_account_class_hash The class hash of the uninitialized account used for deterministic address calculation.
    // @param cairo1_helpers_class_hash The precompiles class hash for precompiles not implemented in Kakarot.
    // @param block_gas_limit The block gas limit.
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt,
        native_token_address,
        account_contract_class_hash,
        uninitialized_account_class_hash,
        cairo1_helpers_class_hash,
        block_gas_limit,
    ) {
        Ownable.initializer(owner);
        Kakarot_native_token_address.write(native_token_address);
        Kakarot_account_contract_class_hash.write(account_contract_class_hash);
        Kakarot_uninitialized_account_class_hash.write(uninitialized_account_class_hash);
        Kakarot_cairo1_helpers_class_hash.write(cairo1_helpers_class_hash);
        Kakarot_block_gas_limit.write(block_gas_limit);
        return ();
    }

    // @notice The eth_call function as described in the RPC spec, see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
    // @param nonce The transaction nonce.
    // @param origin The address the transaction is sent from.
    // @param to The address the transaction is directed to.
    // @param gas_limit Integer of the gas provided for the transaction execution
    // @param gas_price Integer of the gas price used for each paid gas
    // @param value Integer of the value sent with this transaction
    // @param data_len The length of the data
    // @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
    // @param access_list_len The length of the access list
    // @param access_list The access list provided in the transaction serialized as a list of [address, storage_keys_len, ...storage_keys]
    // @return evm The EVM post-execution
    // @return state The state post-execution
    // @return gas_used the gas used by the transaction
    func eth_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        nonce: felt,
        origin: felt,
        to: model.Option,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256*,
        data_len: felt,
        data: felt*,
        access_list_len: felt,
        access_list: felt*,
    ) -> (model.EVM*, model.State*, felt, felt) {
        alloc_locals;
        let is_regular_tx = is_not_zero(to.is_some);
        let is_deploy_tx = 1 - is_regular_tx;
        let evm_contract_address = resolve_to(to, origin, nonce);
        let starknet_contract_address = Account.get_starknet_address(evm_contract_address);
        tempvar address = new model.Address(
            starknet=starknet_contract_address, evm=evm_contract_address
        );
        let (bytecode_len, bytecode) = Starknet.get_bytecode(address.evm);
        let (chain_id) = eth_chain_id();
        let env = Starknet.get_env(origin, gas_price, chain_id);

        let (evm, stack, memory, state, gas_used, required_gas) = Interpreter.execute(
            env,
            address,
            is_deploy_tx,
            bytecode_len,
            bytecode,
            data_len,
            data,
            value,
            gas_limit,
            access_list_len,
            access_list,
        );
        return (evm, state, gas_used, required_gas);
    }

    // @return chain_id The chain ID.
    func eth_chain_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        chain_id: felt
    ) {
        let (tx_info) = get_tx_info();
        let (_, chain_id) = unsigned_div_rem(tx_info.chain_id, 2 ** 53);
        return (chain_id=chain_id);
    }

    // @notice Set the native Starknet ERC20 token used by kakarot.
    // @dev Set the native token which will emulate the role of ETH on Ethereum.
    // @param native_token_address The address of the native token.
    func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        native_token_address: felt
    ) {
        Kakarot_native_token_address.write(native_token_address);
        return ();
    }

    // @notice Get the native token address
    // @dev Return the address used to emulate the role of ETH on Ethereum
    // @return native_token_address The address of the native token
    func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        native_token_address: felt
    ) {
        let (native_token_address) = Kakarot_native_token_address.read();
        return (native_token_address,);
    }

    // @notice Set the block base fee.
    // @param base_fee The new base fee.
    func set_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        base_fee: felt
    ) {
        Kakarot_base_fee.write(base_fee);
        return ();
    }

    // @notice Get the block base fee.
    // @return base_fee The current block base fee.
    func get_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        base_fee: felt
    ) {
        let (base_fee) = Kakarot_base_fee.read();
        return (base_fee,);
    }

    // @notice Set the coinbase address.
    // @param coinbase The new coinbase address.
    func set_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        coinbase: felt
    ) {
        Kakarot_coinbase.write(coinbase);
        return ();
    }

    // @notice Get the coinbase address.
    // @return coinbase The current Kakarot_coinbase.
    func get_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        coinbase: felt
    ) {
        let (coinbase) = Kakarot_coinbase.read();
        return (coinbase,);
    }

    // @notice Set the prev_randao.
    // @param prev_randao The new prev_randao.
    func set_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        prev_randao: Uint256
    ) {
        Kakarot_prev_randao.write(prev_randao);
        return ();
    }

    // @notice Get the prev_randao.
    // @return prev_randao The current prev_randao.
    func get_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        prev_randao: Uint256
    ) {
        let (prev_randao) = Kakarot_prev_randao.read();
        return (prev_randao,);
    }

    // @notice Set the block gas limit.
    // @param block_gas_limit The new block gas limit.
    func set_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        block_gas_limit: felt
    ) {
        Kakarot_block_gas_limit.write(block_gas_limit);
        return ();
    }

    // @notice Get the block gas limit.
    // @return block_gas_limit The current block gas limit.
    func get_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        block_gas_limit: felt
    ) {
        let (block_gas_limit) = Kakarot_block_gas_limit.read();
        return (block_gas_limit=block_gas_limit);
    }

    // @notice Deploy a new externally owned account.
    // @param evm_contract_address The evm address that is mapped to the newly deployed starknet contract address.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_externally_owned_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_contract_address: felt) -> (starknet_contract_address: felt) {
        alloc_locals;
        let (starknet_contract_address) = Starknet.deploy(evm_contract_address);
        return (starknet_contract_address=starknet_contract_address);
    }

    // @notice Set the account implementation class hash
    // @param account_contract_class_hash The new account implementation class hash
    func set_account_contract_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(account_contract_class_hash: felt) {
        Kakarot_account_contract_class_hash.write(account_contract_class_hash);
        return ();
    }

    // @notice Return the class hash of the account implementation
    // @return account_contract_class_hash The class hash of the account implementation
    func get_account_contract_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() -> (account_contract_class_hash: felt) {
        let (account_contract_class_hash) = Kakarot_account_contract_class_hash.read();
        return (account_contract_class_hash,);
    }

    // @notice Set the transparent account class hash
    // @param uninitialized_account_class_hash The new account implementation class hash
    func set_uninitialized_account_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(uninitialized_account_class_hash: felt) {
        Kakarot_uninitialized_account_class_hash.write(uninitialized_account_class_hash);
        return ();
    }

    // @notice Return the class hash of the account implementation
    // @return uninitialized_account_class_hash The class hash of the account implementation
    func get_uninitialized_account_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() -> (uninitialized_account_class_hash: felt) {
        let (uninitialized_account_class_hash) = Kakarot_uninitialized_account_class_hash.read();
        return (uninitialized_account_class_hash,);
    }

    // @return cairo1_helpers_class_hash The hash of the Cairo1Helpers class.
    func get_cairo1_helpers_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() -> (cairo1_helpers_class_hash: felt) {
        let (cairo1_helpers_class_hash) = Kakarot_cairo1_helpers_class_hash.read();
        return (cairo1_helpers_class_hash,);
    }

    // @notice Set the hash of the Cairo1Helpers class
    // @param cairo1_helpers_class_hash The hash of the Cairo1Helpers class
    func set_cairo1_helpers_class_hash{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(cairo1_helpers_class_hash: felt) {
        Kakarot_cairo1_helpers_class_hash.write(cairo1_helpers_class_hash);
        return ();
    }

    // @notice Sets the authorization of an EVM address to call Cairo Precompiles
    // @param evm_address The EVM address
    // @param authorized Whether the EVM address is authorized or not
    func set_authorized_cairo_precompile_caller{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_address: felt, authorized: felt) {
        Kakarot_authorized_cairo_precompiles_callers.write(evm_address, authorized);
        return ();
    }

    // @notice Register the calling Starknet address for the given EVM address
    // @dev    Only the corresponding computed Starknet address can make this call to ensure that registered accounts are actually deployed.
    // @param evm_address The EVM address of the account.
    func register_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) {
        alloc_locals;

        let (existing_address) = Kakarot_evm_to_starknet_address.read(evm_address);
        with_attr error_message("Kakarot: account already registered") {
            assert existing_address = 0;
        }

        let (local caller_address: felt) = get_caller_address();
        let starknet_address = Account.compute_starknet_address(evm_address);
        local starknet_address = starknet_address;

        with_attr error_message(
                "Kakarot: Caller should be {starknet_address}, got {caller_address}") {
            assert starknet_address = caller_address;
        }

        evm_contract_deployed.emit(evm_address, starknet_address);
        Kakarot_evm_to_starknet_address.write(evm_address, starknet_address);
        return ();
    }

    // @notice Writes to an account's bytecode
    // @param evm_address The evm address of the account.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The bytecode to write.
    func write_account_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt, bytecode_len: felt, bytecode: felt*
    ) {
        alloc_locals;
        let starknet_address = Account.get_starknet_address(evm_address);
        IAccount.write_bytecode(starknet_address, bytecode_len, bytecode);
        let code_hash = Account.compute_code_hash(bytecode_len, bytecode);
        IAccount.set_code_hash(starknet_address, code_hash);
        return ();
    }

    // @notice Writes to an account's nonce
    // @param evm_address The evm address of the account.
    // @param nonce The nonce to write.
    func write_account_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt, nonce: felt
    ) {
        alloc_locals;
        let starknet_address = Account.get_starknet_address(evm_address);
        IAccount.set_nonce(starknet_address, nonce);
        return ();
    }

    // @notice Upgrades an account to a new contract implementation.
    // @param evm_address The evm address of the account.
    // @param new_class_hash The new class hash of the account.
    func upgrade_account{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt, new_class_hash: felt
    ) {
        alloc_locals;
        let starknet_address = Account.get_starknet_address(evm_address);
        IAccount.upgrade(starknet_address, new_class_hash);
        return ();
    }

    // @notice Get the EVM address from the transaction
    // @dev When to=None, it's a deploy tx so we first compute the target address
    // @param to The transaction to parameter
    // @param origin The transaction origin parameter
    // @param nonce The transaction nonce parameter, used to compute the target address if it's a deploy tx
    // @return the target evm address
    func resolve_to{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(to: model.Option, origin: felt, nonce: felt) -> felt {
        alloc_locals;
        if (to.is_some != 0) {
            return to.value;
        }
        let (local evm_contract_address) = CreateHelper.get_create_address(origin, nonce);
        return evm_contract_address;
    }

    // @notice returns the EVM address associated to a Starknet account deployed by kakarot.
    //         Prevents cases where some Starknet account has an entrypoint get_evm_address()
    //         but isn't part of Kakarot system
    // Also mitigates re-entrancy risk with the Cairo Interop module
    // @dev Raise if the declared corresponding evm address (retrieved with get_evm_address)
    //      does not recomputes into to the actual caller address
    func safe_get_evm_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(starknet_address: felt) -> (evm_address: felt) {
        alloc_locals;
        let (local evm_address) = IAccount.get_evm_address(starknet_address);
        let computed_starknet_address = Account.get_starknet_address(evm_address);

        with_attr error_message("Kakarot: caller contract is not a Kakarot Account") {
            assert computed_starknet_address = starknet_address;
        }

        return (evm_address=evm_address);
    }

    func set_l1_messaging_contract_address{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(l1_messaging_contract_address: felt) {
        Kakarot_l1_messaging_contract_address.write(l1_messaging_contract_address);
        return ();
    }

    func get_l1_messaging_contract_address{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }() -> felt {
        let (l1_messaging_contract_address) = Kakarot_l1_messaging_contract_address.read();
        return l1_messaging_contract_address;
    }

    func handle_l1_message{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(l1_sender: felt, to_address: felt, value: felt, data_len: felt, data: felt*) -> (
        model.EVM*, model.State*, felt, felt
    ) {
        // TODO: ensure fair gas limits and prices
        let (val_high, val_low) = split_felt(value);
        tempvar value_u256 = new Uint256(low=val_low, high=val_high);
        let to = model.Option(is_some=1, value=to_address);
        let (access_list) = alloc();

        return eth_call(
            0, l1_sender, to, 2100000000, 1, value_u256, data_len, data, 0, access_list
        );
    }
}
