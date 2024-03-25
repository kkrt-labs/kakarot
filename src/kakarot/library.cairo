// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.uint256 import Uint256

from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.storages import (
    uninitialized_account_class_hash,
    contract_account_class_hash,
    base_fee,
    native_token_address,
    precompiles_class_hash,
    coinbase,
    prev_randao,
    block_gas_limit,
)
from kakarot.interpreter import Interpreter
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.model import model

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
namespace Kakarot {
    // @notice The constructor of the contract.
    // @dev Set up the initial owner, accounts class hash and native token.
    // @param owner The address of the owner of the contract.
    // @param native_token_address_ The ERC20 contract used to emulate ETH.
    // @param contract_account_class_hash_ The clash hash of the contract account.
    // @param uninitialized_account_class_hash The class hash of the uninitialized account used for deterministic address calculation.
    // @param precompiles_class_hash_ The precompiles class hash for precompiles not implemented in Kakarot.
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt,
        native_token_address_,
        contract_account_class_hash_,
        uninitialized_account_class_hash_,
        precompiles_class_hash_,
        block_gas_limit_,
    ) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        contract_account_class_hash.write(contract_account_class_hash_);
        uninitialized_account_class_hash.write(uninitialized_account_class_hash_);
        precompiles_class_hash.write(precompiles_class_hash_);
        coinbase.write(0xCA40796aFB5472abaeD28907D5ED6FC74c04954a);
        block_gas_limit.write(block_gas_limit_);
        return ();
    }

    // @notice The eth_call function as described in the RPC spec, see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
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
    ) -> (model.EVM*, model.State*, felt) {
        alloc_locals;
        let is_regular_tx = is_not_zero(to.is_some);
        let is_deploy_tx = 1 - is_regular_tx;
        let evm_contract_address = resolve_to(to, origin, nonce);
        let starknet_contract_address = Account.compute_starknet_address(evm_contract_address);
        tempvar address = new model.Address(
            starknet=starknet_contract_address, evm=evm_contract_address
        );

        let (bytecode_len, bytecode) = Starknet.get_bytecode(address.evm);

        let env = Starknet.get_env(origin, gas_price);

        let (evm, stack, memory, state, gas_used) = Interpreter.execute(
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
        return (evm, state, gas_used);
    }

    // @notice Set the native Starknet ERC20 token used by kakarot.
    // @dev Set the native token which will emulate the role of ETH on Ethereum.
    // @param native_token_address_ The address of the native token.
    func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        native_token_address_: felt
    ) {
        Ownable.assert_only_owner();
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice Get the native token address
    // @dev Return the address used to emulate the role of ETH on Ethereum
    // @return native_token_address The address of the native token
    func get_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        native_token_address: felt
    ) {
        let (native_token_address_) = native_token_address.read();
        return (native_token_address_,);
    }

    // @notice Set the block base fee.
    // @param base_fee_ The new base fee.
    func set_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        base_fee_: felt
    ) {
        Ownable.assert_only_owner();
        base_fee.write(base_fee_);
        return ();
    }

    // @notice Get the block base fee.
    // @return base_fee The current block base fee.
    func get_base_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        base_fee: felt
    ) {
        let (base_fee_) = base_fee.read();
        return (base_fee_,);
    }

    // @notice Set the coinbase address.
    // @param coinbase_ The new coinbase address.
    func set_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        coinbase_: felt
    ) {
        Ownable.assert_only_owner();
        coinbase.write(coinbase_);
        return ();
    }

    // @notice Get the coinbase address.
    // @return coinbase The current coinbase.
    func get_coinbase{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        coinbase: felt
    ) {
        let (coinbase_) = coinbase.read();
        return (coinbase_,);
    }

    // @notice Set the prev_randao.
    // @param prev_randao_ The new prev_randao.
    func set_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        prev_randao_: Uint256
    ) {
        Ownable.assert_only_owner();
        prev_randao.write(prev_randao_);
        return ();
    }

    // @notice Get the prev_randao.
    // @return prev_randao The current prev_randao.
    func get_prev_randao{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        prev_randao: Uint256
    ) {
        let (prev_randao_) = prev_randao.read();
        return (prev_randao_,);
    }

    // @notice Set the block gas limit.
    // @param block_gas_limit_ The new block gas limit.
    func set_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        block_gas_limit_: felt
    ) {
        Ownable.assert_only_owner();
        block_gas_limit.write(block_gas_limit_);
        return ();
    }

    // @notice Get the block gas limit.
    // @return block_gas_limit The current block gas limit.
    func get_block_gas_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        block_gas_limit: felt
    ) {
        let (block_gas_limit_) = block_gas_limit.read();
        return (block_gas_limit_,);
    }

    // @notice Deploy a new externally owned account.
    // @param evm_contract_address The evm address that is mapped to the newly deployed starknet contract address.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_externally_owned_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_contract_address: felt) -> (starknet_contract_address: felt) {
        alloc_locals;

        let (class_hash) = uninitialized_account_class_hash.read();
        let (starknet_contract_address) = Starknet.deploy(class_hash, evm_contract_address);

        return (starknet_contract_address=starknet_contract_address);
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
        let computed_starknet_address = Account.compute_starknet_address(evm_address);

        with_attr error_message("Kakarot: caller contract is not a Kakarot Account") {
            assert computed_starknet_address = starknet_address;
        }

        return (evm_address=evm_address);
    }
}
