// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.starknet.common.syscalls import deploy as deploy_syscall
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info

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
from kakarot.interfaces.interfaces import IAccount, IContractAccount, IERC20
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
    // @dev starknet_contract_address and evm_contract_address can be set to 0 if
    //      there is no notion of deployed contract in the bytecode. Otherwise,
    //      they should match (ie. that compute_starknet_address(IAccount.get_evm_address(starknet_contract_address))
    //      should equal starknet_contract_address. In a future version, either one or the
    //      other will be removed
    // @param starknet_contract_address The starknet contract address of the called contract
    // @param evm_contract_address The corresponding EVM contract address of the called contract
    // @param origin The caller EVM address
    // @param bytecode_len The length of the bytecode
    // @param bytecode The bytecode run
    // @param calldata_len The length of the calldata
    // @param calldata The calldata of the execution
    // @param value The value of the execution
    // @param gas_limit The gas limit of the execution
    // @param gas_price The gas price for the execution
    // @param reverted Whether the transaction is reverted or not
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        starknet_contract_address: felt,
        evm_contract_address: felt,
        origin: felt,
        bytecode_len: felt,
        bytecode: felt*,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        gas_limit: felt,
        gas_price: felt,
    ) -> (
        stack_accesses_len: felt,
        stack_accesses: felt*,
        stack_len: felt,
        memory_accesses_len: felt,
        memory_accesses: felt*,
        memory_bytes_len: felt,
        starknet_contract_address: felt,
        evm_contract_address: felt,
        return_data_len: felt,
        return_data: felt*,
        gas_used: felt,
        reverted: felt,
    ) {
        alloc_locals;

        // Prepare execution context
        let root_context = ExecutionContext.init_empty();
        tempvar address = new model.Address(starknet_contract_address, evm_contract_address);
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
        );

        let ctx = ExecutionContext.init(call_context);

        let cost = ExecutionContext.compute_intrinsic_gas_cost(ctx);
        let transfer = make_transfer(origin, evm_contract_address, value);
        let state = State.add_transfer(ctx.state, transfer);

        let ctx = ExecutionContext.update_state(ctx, state);
        let ctx = ExecutionContext.increment_gas_used(ctx, cost);

        let summary = EVM.run(ctx);

        let memory_accesses_len = summary.memory.squashed_end - summary.memory.squashed_start;
        let stack_accesses_len = summary.stack.squashed_end - summary.stack.squashed_start;

        return (
            stack_accesses_len=stack_accesses_len,
            stack_accesses=summary.stack.squashed_start,
            stack_len=summary.stack.len_16bytes,
            memory_accesses_len=memory_accesses_len,
            memory_accesses=summary.memory.squashed_start,
            memory_bytes_len=summary.memory.bytes_len,
            starknet_contract_address=summary.address.starknet,
            evm_contract_address=summary.address.evm,
            return_data_len=summary.return_data_len,
            return_data=summary.return_data,
            gas_used=summary.gas_used,
            reverted=summary.reverted,
        );
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

    // @notice Transfer "value" native tokens from "origin" to "to"
    // @param origin The sender address.
    // @param to_ The address the transaction is directed to.
    // @param value Integer of the value sent with this transaction
    // @return success Boolean to indicate success or failure of transfer
    func make_transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        origin: felt, to_: felt, value: felt
    ) -> model.Transfer* {
        alloc_locals;
        let (local sender_starknet_address) = Accounts.compute_starknet_address(origin);
        let (local recipient_starknet_address) = Accounts.compute_starknet_address(to_);
        tempvar sender = new model.Address(sender_starknet_address, origin);
        tempvar recipient = new model.Address(to_, recipient_starknet_address);
        let amount = Helpers.to_uint256(value);
        return new model.Transfer(sender, recipient, amount);
    }

    // @notice Deploy contract account.
    // @dev First deploy a contract_account with no bytecode, then run the calldata as bytecode with the new address,
    //      then set the bytecode with the result of the initial run.
    // @param origin The origin for the transaction
    // @param evm_contract_address The evm address of the contract to be deployed
    // @param value The value to be transferred as part of this deploy call
    // @param bytecode_len The deploy bytecode length.
    // @param bytecode The deploy bytecode.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_contract_account{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        origin: felt, evm_contract_address: felt, value: felt, bytecode_len: felt, bytecode: felt*
    ) -> (starknet_contract_address: felt, reverted: felt) {
        alloc_locals;

        let (class_hash) = contract_account_class_hash.read();
        let (starknet_contract_address) = Accounts.create(class_hash, evm_contract_address);
        let (empty_array: felt*) = alloc();

        let (
            stack_accesses_len,
            stack_accesses,
            stack_len,
            memory_accesses_len,
            memory_accesses,
            memory_bytes_len,
            starknet_contract_address,
            evm_contract_address,
            return_data_len,
            return_data,
            gas_used,
            reverted,
        ) = execute(
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            origin=origin,
            bytecode_len=bytecode_len,
            bytecode=bytecode,
            calldata_len=0,
            calldata=empty_array,
            value=value,
            gas_limit=Constants.TRANSACTION_GAS_LIMIT,
            gas_price=0,
        );

        return (starknet_contract_address=starknet_contract_address, reverted=reverted);
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
    ) -> (return_data_len: felt, return_data: felt*, success: felt) {
        alloc_locals;

        if (to == 0) {
            // TODO: read the nonce from the provided origin address, otherwise in view mode this will
            // TODO: always use a 0 nonce
            let (tx_info) = get_tx_info();
            let (evm_contract_address) = CreateHelper.get_create_address(origin, tx_info.nonce);
            let (starknet_contract_address, reverted) = deploy_contract_account(
                origin=origin,
                evm_contract_address=evm_contract_address,
                value=value,
                bytecode_len=data_len,
                bytecode=data,
            );
            let (return_data) = alloc();
            assert [return_data] = evm_contract_address;
            assert [return_data + 1] = starknet_contract_address;
            return (2, return_data, 1 - reverted);
        } else {
            let (local starknet_contract_address) = Accounts.compute_starknet_address(to);
            let (bytecode_len, bytecode) = Accounts.get_bytecode(to);
            let summary = execute(
                starknet_contract_address,
                to,
                origin,
                bytecode_len,
                bytecode,
                data_len,
                data,
                value,
                gas_limit,
                gas_price,
            );
            return (summary.return_data_len, summary.return_data, 1 - summary.reverted);
        }
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

    // @notice Since it's possible in starknet to send a transcation to a @view entrypoint, this
    //         ensures that there is no ongoing transaction (so it's really a view call).
    // @dev Raise if tx_info.account_contract_address is not 0
    func assert_view{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() {
        let (tx_info) = get_tx_info();
        with_attr error_message("Kakarot: entrypoint should only be called in view mode") {
            assert tx_info.account_contract_address = 0;
        }

        return ();
    }
}
