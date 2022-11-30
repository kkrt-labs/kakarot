// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy as deploy_syscall
from starkware.starknet.common.syscalls import get_contract_address
// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.stack import Stack
from kakarot.instructions import EVMInstructions
from kakarot.interfaces.interfaces import IRegistry, IEvmContract
from kakarot.execution_context import ExecutionContext
from kakarot.constants import native_token_address, registry_address, evm_contract_class_hash

@storage_var
func salt() -> (value: felt) {
}

// An event emitted whenever kakarot deploys a evm contract
// evm_contract_address is the representation of the evm address of the contract
// starknet_contract_address if the starknet address of the contract
@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
// @author @abdelhamidbakhta
// @custom:namespace Kakarot
namespace Kakarot {
    // @notice The constructor of the contract
    // @dev Setting initial owner, contract account class hash and native token
    // @param owner The address of the owner of the contract
    // @param native_token_address_ The ERC20 contract used to emulate ETH
    // @param evm_contract_class_hash_ The clash hash of the contract account
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, native_token_address_, evm_contract_class_hash_: felt
    ) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        evm_contract_class_hash.write(
        evm_contract_class_hash_);
        return ();
    }

    // @notice Execute EVM bytecode.
    // @dev Executes a provided array of evm opcodes/bytecode
    // @param code_len The bytecode length
    // @param code The bytecode to execute
    // @param calldata The calldata which can be referenced by the bytecode
    // @return The pointer to the execution context.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(call_context: model.CallContext*) -> ExecutionContext.Summary* {
        alloc_locals;

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(self=ctx);

        // Start execution
        let ctx = run(ctx=ctx);

        // Finalize
        // TODO: Consider finalizing on `ret` instruction, to get the memory efficiently.
        let summary = ExecutionContext.finalize(self=ctx);

        return summary;
    }

    // @notice execute bytecode of a given EVM contract
    // @dev reads the bytecode content of an EVM contract and then executes it
    // @param address The address of the contract whose bytecode will be executed
    // @param calldata The calldata which contains the entry point and method parameters
    // @return The pointer to the updated execution context.
    func execute_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: felt, calldata_len: felt, calldata: felt*, value: felt
    ) -> ExecutionContext.Summary* {
        alloc_locals;

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init_at_address(
            address=address, calldata_len=calldata_len, calldata=calldata, value=value
        );

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(ctx);

        // Finalize
        // TODO: Consider finalizing on `ret` instruction, to get the memory efficiently.
        let summary = ExecutionContext.finalize(self=ctx);

        return summary;
    }

    // @notice Run the execution of the bytecode.
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Decode and execute
        let ctx: model.ExecutionContext* = EVMInstructions.decode_and_execute(ctx=ctx);

        // Check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(self=ctx);

        // Terminate execution
        if (stopped != FALSE) {
            return ctx;
        }

        // Continue execution
        return run(ctx=ctx);
    }

    // @notice Set the account registry used by kakarot
    // @dev Set the account regestry which will be used to convert
    //      given starknet addresses to evm addresses and vice versa
    // @param registry_address_ The address of the new account registry contract
    func set_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        registry_address_: felt
    ) {
        Ownable.assert_only_owner();
        registry_address.write(registry_address_);
        return ();
    }

    // @notice Get the account registry used by kakarot
    // @return address The address of the current account registry contract
    func get_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ) -> (address: felt) {
        let (reg_address) = registry_address.read();
        return (reg_address,);
    }

    // @notice Set the native token used by kakarot
    // @dev Set the native token which will emulate the role of ETH on Ethereum
    // @param native_token_address_ The address of the native token
    func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        native_token_address_: felt
    ) {
        Ownable.assert_only_owner();
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice deploy contract account
    // @dev First deploy a contract_account with no bytecode, then run the calldata as bytecode with the new address,
    //      then set the bytecode with the result of the initial run
    // @param bytecode_len: the deploy bytecode length
    // @param bytecode: the deploy bytecode
    // @return evm_contract_address The evm address that is mapped to the newly deployed starknet contract address
    // @return starknet_contract_address The newly deployed starknet contract address
    func deploy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) -> (
        evm_contract_address: felt, starknet_contract_address: felt
    ) {
        alloc_locals;
        let (current_salt) = salt.read();
        let (class_hash) = evm_contract_class_hash.read();

        // Prepare constructor data
        let (local calldata: felt*) = alloc();
        let (kakarot_address) = get_contract_address();
        assert [calldata] = kakarot_address;
        assert [calldata + 1] = 0;

        // Deploy contract account with no bytecode
        let (starknet_contract_address) = deploy_syscall(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=2,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE,
        );

        // Increment salt
        salt.write(value=current_salt + 1);

        // Generate EVM_contract address from the new cairo contract
        // TODO: TEMPORARY SOLUTION FOR HACK-LISBON !!!
        let (_, low) = split_felt(starknet_contract_address);
        local evm_contract_address = 0xAbdE100700000000000000000000000000000000 + low;

        evm_contract_deployed.emit(
            evm_contract_address=evm_contract_address,
            starknet_contract_address=starknet_contract_address,
        );

        // Save address of new contracts
        let (reg_address) = registry_address.read();
        IRegistry.set_account_entry(reg_address, starknet_contract_address, evm_contract_address);

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
        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();
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
            intrinsic_gas_cost=0,
            starknet_contract_address=starknet_contract_address,
            evm_contract_address=evm_contract_address,
            );

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(ctx);

        // Update contract bytecode with execution result
        IEvmContract.write_bytecode(
            contract_address=starknet_contract_address,
            bytecode_len=ctx.return_data_len,
            bytecode=ctx.return_data,
        );

        return (
            evm_contract_address=evm_contract_address,
            starknet_contract_address=starknet_contract_address,
        );
    }
}
