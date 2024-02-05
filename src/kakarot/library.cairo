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
    account_proxy_class_hash,
    contract_account_class_hash,
    deploy_fee,
    externally_owned_account_class_hash,
    native_token_address,
    precompiles_class_hash,
    coinbase
)
from kakarot.interpreter import Interpreter
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.model import model
from utils.utils import Helpers

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
namespace Kakarot {
    // @notice The constructor of the contract.
    // @dev Set up the initial owner, accounts class hash and native token.
    // @param owner The address of the owner of the contract.
    // @param native_token_address_ The ERC20 contract used to emulate ETH.
    // @param contract_account_class_hash_ The clash hash of the contract account.
    // @param externally_owned_account_class_hash_ The externally owned account class hash.
    // @param account_proxy_class_hash_ The account proxy class hash.
    // @param deploy_fee_ The deploy fee for deploying EOA on Kakarot.
    // @param precompiles_class_hash_ The precompiles class hash for precompiles not implemented in Kakarot.
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt,
        native_token_address_,
        contract_account_class_hash_,
        externally_owned_account_class_hash_,
        account_proxy_class_hash_,
        deploy_fee_,
        precompiles_class_hash_,
    ) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        contract_account_class_hash.write(contract_account_class_hash_);
        externally_owned_account_class_hash.write(externally_owned_account_class_hash_);
        account_proxy_class_hash.write(account_proxy_class_hash_);
        deploy_fee.write(deploy_fee_);
        precompiles_class_hash.write(precompiles_class_hash_);
        coinbase.write(0xCA40796aFB5472abaeD28907D5ED6FC74c04954a);
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
        origin: felt,
        to: felt,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256*,
        data_len: felt,
        data: felt*,
        access_list_len: felt,
        access_list: felt*,
    ) -> (model.EVM*, model.State*, felt) {
        alloc_locals;
        let evm_contract_address = resolve_to(to, origin);
        let starknet_contract_address = Account.compute_starknet_address(evm_contract_address);
        tempvar address = new model.Address(
            starknet=starknet_contract_address, evm=evm_contract_address
        );

        let is_regular_tx = is_not_zero(to);
        let is_deploy_tx = 1 - is_regular_tx;
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

    // @notice Set the deploy fee for deploying EOA on Kakarot.
    // @dev Set the deploy fee to be returned to a deployer for deploying accounts.
    // @param deploy_fee_ The new deploy fee.
    func set_deploy_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        deploy_fee_: felt
    ) {
        Ownable.assert_only_owner();
        deploy_fee.write(deploy_fee_);
        return ();
    }

    // @notice Get the deploy fee for deploying EOA on Kakarot.
    // @dev Return the deploy fee which is returned to a deployer for deploying accounts.
    // @return deploy_fee The deploy fee which is returned to a deployer for deploying accounts.
    func get_deploy_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        deploy_fee: felt
    ) {
        let (deploy_fee_) = deploy_fee.read();
        return (deploy_fee_,);
    }

    // @notice Deploy a new externally owned account.
    // @param evm_contract_address The evm address that is mapped to the newly deployed starknet contract address.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_externally_owned_account{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(evm_contract_address: felt) -> (starknet_contract_address: felt) {
        alloc_locals;

        let (class_hash) = externally_owned_account_class_hash.read();
        let (starknet_contract_address) = Starknet.deploy(class_hash, evm_contract_address);

        let (local native_token_address) = get_native_token();
        let (local deploy_fee) = get_deploy_fee();

        let amount = Helpers.to_uint256(deploy_fee);
        let (caller_address) = get_caller_address();
        let (success) = IERC20.transferFrom(
            contract_address=native_token_address,
            sender=starknet_contract_address,
            recipient=caller_address,
            amount=[amount],
        );

        return (starknet_contract_address=starknet_contract_address);
    }

    // @notice Get the EVM address from the transaction
    // @dev When to=0, it's a deploy tx so we first compute the target address
    // @param to The transaction to parameter
    // @param origin The transaction origin parameter
    // @return the target evm address
    func resolve_to{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(to: felt, origin: felt) -> felt {
        alloc_locals;
        if (to != 0) {
            return to;
        }
        // TODO: read the nonce from the provided origin address, otherwise in view mode this will
        // TODO: always use a 0 nonce
        let (tx_info) = get_tx_info();
        let (local evm_contract_address) = CreateHelper.get_create_address(origin, tx_info.nonce);
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
