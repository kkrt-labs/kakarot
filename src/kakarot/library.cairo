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
    native_token_address,
    contract_account_class_hash,
    externally_owned_account_class_hash,
    blockhash_registry_address,
    account_proxy_class_hash,
)
from kakarot.execution_context import ExecutionContext
from kakarot.instructions import EVMInstructions
from kakarot.instructions.system_operations import CreateHelper
from kakarot.interfaces.interfaces import IAccount, IContractAccount, IEth
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.utils import Helpers

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
// @author @abdelhamidbakhta
// @custom:namespace Kakarot
namespace Kakarot {
    // @notice The constructor of the contract.
    // @dev Set up the initial owner, contract account class hash and native token.
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
    ) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        contract_account_class_hash.write(contract_account_class_hash_);
        externally_owned_account_class_hash.write(externally_owned_account_class_hash_);
        account_proxy_class_hash.write(account_proxy_class_hash_);
        return ();
    }

    // @notice Execute EVM bytecode.
    // @dev Execute a provided array of evm opcodes/bytes.
    // @param value The deposited value by the instruction/transaction responsible for this execution.
    // @param bytecode_len The bytecode length.
    // @param bytecode The bytecode to be executed.
    // @param calldata_len The calldata length.
    // @param calldata The calldata which can be referenced by the bytecode.
    // @return stack_accesses_len The size of the accesses array of the stack delta.
    // @return stack_accesses The dict accesses in the stack delta.
    // @return stack_len The length of the stack.
    // @return memory_accesses_len The size of the accesses arrayof the memory delta.
    // @return memory_accesses The dict accesses in the memory delta.
    // @return memory_bytes_len The memory length.
    // @return memory The EVM memory content.
    // @return gas_used The total amount of gas used to execute the given bytecode.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(value: felt, bytecode_len: felt, bytecode: felt*, calldata_len: felt, calldata: felt*) -> (
        stack_accesses_len: felt,
        stack_accesses: felt*,
        stack_len: felt,
        memory_accesses_len: felt,
        memory_accesses: felt*,
        memory_bytes_len: felt,
        return_data_len: felt,
        return_data: felt*,
        gas_used: felt,
    ) {
        alloc_locals;
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=calldata,
            calldata_len=calldata_len,
            value=value,
        );

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);

        // Compute intrinsic gas cost and update gas used
        let cost = ExecutionContext.compute_intrinsic_gas_cost(self=ctx);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=cost);

        // Start execution
        let ctx = EVMInstructions.run(ctx=ctx);

        // Finalize
        // TODO: Consider finalizing on `ret` instruction, to get the memory efficiently.
        let summary = ExecutionContext.finalize(self=ctx);

        let memory_accesses_len = summary.memory.squashed_end - summary.memory.squashed_start;
        let stack_accesses_len = summary.stack.squashed_end - summary.stack.squashed_start;

        return (
            stack_accesses_len=stack_accesses_len,
            stack_accesses=summary.stack.squashed_start,
            stack_len=summary.stack.len_16bytes,
            memory_accesses_len=memory_accesses_len,
            memory_accesses=summary.memory.squashed_start,
            memory_bytes_len=summary.memory.bytes_len,
            return_data_len=summary.return_data_len,
            return_data=summary.return_data,
            gas_used=summary.gas_used,
        );
    }

    // @notice execute bytecode of a given EVM contract.
    // @dev reads the bytecode content of an EVM contract and then executes it.
    // @param address The address of the contract whose bytecode will be executed.
    // @param calldata_len The length of the calldata array.
    // @param calldata The calldata which contains the entry point and method parameters.
    // @param value The value.
    // @param gas_limit Max gas the transaction can use.
    // @param gas_price Max gas the transaction can use.
    // @return Summary The pointer to the updated execution context.
    func execute_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: felt,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        gas_limit: felt,
        gas_price: felt,
    ) -> ExecutionContext.Summary* {
        alloc_locals;

        // Prepare execution context
        let root_context = ExecutionContext.init_empty();
        let return_data: felt* = alloc();
        let ctx: model.ExecutionContext* = ExecutionContext.init_at_address(
            address=address,
            gas_limit=gas_limit,
            calldata_len=calldata_len,
            calldata=calldata,
            value=value,
            calling_context=root_context,
            return_data_len=0,
            return_data=return_data,
            read_only=FALSE,
        );

        // Compute intrinsic gas cost and update gas used
        let cost = ExecutionContext.compute_intrinsic_gas_cost(ctx);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=cost);

        // Start execution
        let ctx = EVMInstructions.run(ctx);
        ExecutionContext.maybe_throw_revert(ctx);
        // Finalize
        // TODO: Consider finalizing on `ret` instruction, to get the memory efficiently.
        let summary = ExecutionContext.finalize(self=ctx);

        return summary;
    }

    // @notice Set the blockhash registry used by kakarot.
    // @dev Set the blockhash registry which will be used to get the blockhashes.
    // @param blockhash_registry_address_ The address of the new blockhash registry contract.
    func set_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        blockhash_registry_address_: felt
    ) {
        Ownable.assert_only_owner();
        blockhash_registry_address.write(blockhash_registry_address_);
        return ();
    }

    // @notice Get the blockhash registry used by kakarot.
    // @return address The address of the current blockhash registry contract.
    func get_blockhash_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (address: felt) {
        let (blockhash_registry_address_) = blockhash_registry_address.read();
        return (blockhash_registry_address_,);
    }

    // @notice Set the native token used by kakarot.
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

    // @notice The transfer "value" native tokens to "to"
    // @dev "from" parameter is taken from get_caller_address syscall
    // @param to_ The address the transaction is directed to.
    // @param value Integer of the value sent with this transaction
    // @return success Boolean to indicate success or failure of transfer
    func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        to_: felt, value: felt
    ) -> (success: felt) {
        alloc_locals;
        let (local native_token_address) = get_native_token();
        let (from_) = get_caller_address();
        let (recipient) = Accounts.compute_starknet_address(to_);
        let amount = Helpers.to_uint256(value);
        let (success) = IEth.transferFrom(
            contract_address=native_token_address, sender=from_, recipient=recipient, amount=amount
        );
        return (success=success);
    }

    // @notice Deploy contract account.
    // @dev First deploy a contract_account with no bytecode, then run the calldata as bytecode with the new address,
    //      then set the bytecode with the result of the initial run.
    // @param bytecode_len The deploy bytecode length.
    // @param bytecode The deploy bytecode.
    // @return evm_contract_address The evm address that is mapped to the newly deployed starknet contract address.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_contract_account{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) -> (
        evm_contract_address: felt, starknet_contract_address: felt
    ) {
        alloc_locals;
        let (caller_address) = get_caller_address();
        let (sender_evm_address) = IAccount.get_evm_address(caller_address);
        let (nonce) = IAccount.get_nonce(caller_address);
        let (evm_contract_address) = CreateHelper.get_create_address(sender_evm_address, nonce);
        let (class_hash) = contract_account_class_hash.read();
        let (starknet_contract_address) = Accounts.create(class_hash, evm_contract_address);

        // Prepare execution context
        let (empty_array: felt*) = alloc();
        tempvar call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=empty_array,
            calldata_len=0,
            value=0,
        );
        let (local contract_bytecode: felt*) = alloc();
        let (empty_destroy_contracts: felt*) = alloc();
        let (empty_events: model.Event*) = alloc();
        let (empty_create_addresses: felt*) = alloc();
        let (local revert_contract_state_dict_start) = default_dict_new(0);
        tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
            revert_contract_state_dict_start, revert_contract_state_dict_start
        );
        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();
        let calling_context = ExecutionContext.init_empty();
        let sub_context = ExecutionContext.init_empty();
        tempvar ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=call_context,
            program_counter=0,
            stopped=FALSE,
            return_data=contract_bytecode,
            return_data_len=0,
            stack=stack,
            memory=memory,
            gas_used=0,
            gas_limit=0,
            gas_price=0,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            calling_context=calling_context,
            sub_context=sub_context,
            destroy_contracts_len=0,
            destroy_contracts=empty_destroy_contracts,
            events_len=0,
            events=empty_events,
            create_addresses_len=0,
            create_addresses=empty_create_addresses,
            revert_contract_state=revert_contract_state,
            reverted=FALSE,
            read_only=FALSE,
        );

        // Compute intrinsic gas cost and update gas used
        let cost = ExecutionContext.compute_intrinsic_gas_cost(ctx);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=cost);

        // Start execution
        let ctx = EVMInstructions.run(ctx);

        // Update contract bytecode with execution result
        IContractAccount.write_bytecode(
            contract_address=starknet_contract_address,
            bytecode_len=ctx.return_data_len,
            bytecode=ctx.return_data,
        );
        return (
            evm_contract_address=evm_contract_address,
            starknet_contract_address=starknet_contract_address,
        );
    }

    // @notice Deploy a new externally owned account.
    // @param evm_contract_address The evm address that is mapped to the newly deployed starknet contract address.
    // @return starknet_contract_address The newly deployed starknet contract address.
    func deploy_externally_owned_account{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt) -> (starknet_contract_address: felt) {
        let (class_hash) = externally_owned_account_class_hash.read();
        let (starknet_contract_address) = Accounts.create(class_hash, evm_address);
        return (starknet_contract_address=starknet_contract_address);
    }

    // @notice The eth_call function as described in the spec, see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
    // @dev "from" parameter is taken from get_caller_address syscall
    // @param to The address the transaction is directed to.
    // @param gas Integer of the gas provided for the transaction execution
    // @param gas_price Integer of the gasPrice used for each paid gas
    // @param value Integer of the value sent with this transaction
    // @param data_len The length of the data
    // @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
    // @return Summary The pointer to the updated execution context.
    func eth_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*) -> (
        return_data_len: felt, return_data: felt*
    ) {
        let (success) = transfer(to, value);
        with_attr error_message("Kakarot: eth_call: failed to transfer {value} tokens to {to}") {
            assert success = TRUE;
        }

        // TODO: add check that target contract does not exist or has empty bytecode
        if (data_len == 0) {
            let (return_data) = alloc();
            return (0, return_data);
        }

        if (to == 0) {
            let (evm_contract_address, starknet_contract_address) = deploy_contract_account(
                bytecode_len=data_len, bytecode=data
            );
            let (return_data) = alloc();
            assert [return_data] = evm_contract_address;
            assert [return_data + 1] = starknet_contract_address;
            return (2, return_data);
        } else {
            let summary = execute_at_address(
                address=to,
                calldata_len=data_len,
                calldata=data,
                value=value,
                gas_limit=gas_limit,
                gas_price=gas_price,
            );
            return (summary.return_data_len, summary.return_data);
        }
    }

    func assert_caller_is_kakarot_account{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }() {
        let (actual_starknet_address) = get_caller_address();
        let (declared_evm_address) = IAccount.get_evm_address(actual_starknet_address);
        let (computed_starknet_address) = Accounts.compute_starknet_address(declared_evm_address);

        with_attr error_message("Kakarot: caller contract is not a Kakarot Account") {
            assert computed_starknet_address = actual_starknet_address;
        }

        return ();
    }
}
