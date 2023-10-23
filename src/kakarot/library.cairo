// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.starknet.common.syscalls import deploy as deploy_syscall
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info
from starkware.cairo.common.math_cmp import is_not_zero

from kakarot.accounts.library import Accounts
from kakarot.constants import (
    account_proxy_class_hash,
    blockhash_registry_address,
    contract_account_class_hash,
    deploy_fee,
    externally_owned_account_class_hash,
    native_token_address,
)
from kakarot.evm import EVM
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.constants import Constants
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
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt,
        native_token_address_,
        contract_account_class_hash_,
        externally_owned_account_class_hash_,
        account_proxy_class_hash_,
        deploy_fee_,
    ) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        contract_account_class_hash.write(contract_account_class_hash_);
        externally_owned_account_class_hash.write(externally_owned_account_class_hash_);
        account_proxy_class_hash.write(account_proxy_class_hash_);
        deploy_fee.write(deploy_fee_);
        return ();
    }

    // @notice Run the given bytecode with the given calldata and parameters
    // @param address The target account address
    // @param is_deploy_tx Whether the transaction is a deploy tx or not
    // @param origin The caller EVM address
    // @param bytecode_len The length of the bytecode
    // @param bytecode The bytecode run
    // @param calldata_len The length of the calldata
    // @param calldata The calldata of the execution
    // @param value The value of the execution
    // @param gas_limit The gas limit of the execution
    // @param gas_price The gas price for the execution
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: model.Address*,
        is_deploy_tx: felt,
        origin: felt,
        bytecode_len: felt,
        bytecode: felt*,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        gas_limit: felt,
        gas_price: felt,
    ) -> EVM.Summary* {
        alloc_locals;

        // If is_deploy_tx is TRUE, then
        // bytecode is data and data is empty
        // else, bytecode and data are kept as is
        let bytecode_len = calldata_len * is_deploy_tx + bytecode_len * (1 - is_deploy_tx);
        let calldata_len = calldata_len * (1 - is_deploy_tx);
        if (is_deploy_tx != 0) {
            let (empty: felt*) = alloc();
            tempvar bytecode = calldata;
            tempvar calldata = empty;
        } else {
            tempvar bytecode = bytecode;
            tempvar calldata = calldata;
        }

        let root_context = ExecutionContext.init_empty();
        tempvar call_context = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=calldata,
            calldata_len=calldata_len,
            value=value,
            gas_limit=gas_limit,
            gas_price=gas_price,
            origin=origin,
            calling_context=root_context,
            address=address,
            read_only=FALSE,
            is_create=is_deploy_tx,
        );

        let ctx = ExecutionContext.init(call_context);
        let ctx = ExecutionContext.add_intrinsic_gas_cost(ctx);

        let (origin_starknet_address) = Accounts.compute_starknet_address(origin);
        tempvar sender = new model.Address(origin_starknet_address, origin);
        let amount = Helpers.to_uint256(value);
        let transfer = model.Transfer(sender, address, amount);
        let state = State.add_transfer(ctx.state, transfer);
        let ctx = ExecutionContext.update_state(ctx, state);

        let summary = EVM.run(ctx);
        return summary;
    }

    // @notice The eth_call function as described in the RPC spec, see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
    // @param origin The address the transaction is sent from.
    // @param to The address the transaction is directed to.
    // @param gas_limit Integer of the gas provided for the transaction execution
    // @param gas_price Integer of the gas price used for each paid gas
    // @param value Integer of the value sent with this transaction
    // @param data_len The length of the data
    // @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
    // @return return_data_len The length of the returned bytes
    // @return return_data The returned bytes array
    // @return success A boolean TRUE if the transaction succeeded, FALSE if it's reverted
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
        value: felt,
        data_len: felt,
        data: felt*,
    ) -> EVM.Summary* {
        alloc_locals;
        let evm_contract_address = resolve_to(to, origin);
        let (starknet_contract_address) = Accounts.compute_starknet_address(evm_contract_address);
        tempvar address = new model.Address(starknet_contract_address, evm_contract_address);

        let is_regular_tx = is_not_zero(to);
        let is_deploy_tx = 1 - is_regular_tx;
        let (bytecode_len, bytecode) = Accounts.get_bytecode(address.evm);

        let summary = execute(
            address,
            is_deploy_tx,
            origin,
            bytecode_len,
            bytecode,
            data_len,
            data,
            value,
            gas_limit,
            gas_price,
        );
        return summary;
    }

    // @notice The Blockhash registry is used by the BLOCKHASH opcode
    // @dev Set the Blockhash registry contract address
    // @param blockhash_registry_address_ The address of the new blockhash registry contract.
    func set_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        blockhash_registry_address_: felt
    ) {
        Ownable.assert_only_owner();
        blockhash_registry_address.write(blockhash_registry_address_);
        return ();
    }

    // @notice The Blockhash registry is used by the BLOCKHASH opcode
    // @dev Get the Blockhash registry contract address
    // @return address The address of the current blockhash registry contract.
    func get_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (address: felt) {
        let (blockhash_registry_address_) = blockhash_registry_address.read();
        return (blockhash_registry_address_,);
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
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_contract_address: felt) -> (starknet_contract_address: felt) {
        alloc_locals;

        let (class_hash) = externally_owned_account_class_hash.read();
        let (starknet_contract_address) = Accounts.create(class_hash, evm_contract_address);

        let (local native_token_address) = get_native_token();
        let (local deploy_fee) = get_deploy_fee();

        let amount = Helpers.to_uint256(deploy_fee);
        let (caller_address) = get_caller_address();
        let (success) = IERC20.transferFrom(
            contract_address=native_token_address,
            sender=starknet_contract_address,
            recipient=caller_address,
            amount=amount,
        );

        return (starknet_contract_address=starknet_contract_address);
    }

    // @notice Get the ExecutionContext address from the transaction
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
        let (local computed_starknet_address) = Accounts.compute_starknet_address(evm_address);

        with_attr error_message("Kakarot: caller contract is not a Kakarot Account") {
            assert computed_starknet_address = starknet_address;
        }

        return (evm_address=evm_address);
    }
}
