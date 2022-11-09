// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy
from starkware.starknet.common.syscalls import get_contract_address
// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from kakarot.model import model
from kakarot.instructions import EVMInstructions
from kakarot.interfaces.interfaces import IRegistry
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
    // @param _owner The address of the owner of the contract
    // @param native_token_address_ The ERC20 contract used to emulate ETH
    // @param evm_contract_class_hash_ The clash hash of the contract account
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        owner: felt, native_token_address_, evm_contract_class_hash_: felt
    ) {
        Ownable.initializer(owner);
        evm_contract_class_hash.write(evm_contract_class_hash_);
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice Execute EVM bytecode.
    // @dev Executes a provided array of evm opcodes/bytes
    // @param code_len The bytecode length
    // @param code The bytecode to execute
    // @param calldata The calldata which can be referenced by the bytecode
    // @return The pointer to the execution context.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(call_context: model.CallContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(self=ctx);

        // Start execution
        let ctx = run(instructions=instructions, ctx=ctx);

        return ctx;
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
    }(address: felt, calldata_len: felt, calldata: felt*, value: felt) -> model.ExecutionContext* {
        alloc_locals;

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init_at_address(
            address=address, calldata=calldata, calldata_len=calldata_len, value=value
        );

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(instructions, ctx);

        return ctx;
    }

    // @notice Run the execution of the bytecode.
    // @param instructions The instructions set.
    // @param ctx The pointer to the execution context.
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(instructions: felt*, ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Decode and execute
        let ctx: model.ExecutionContext* = EVMInstructions.decode_and_execute(
            instructions=instructions, ctx=ctx
        );

        // Check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(self=ctx);

        // Terminate execution
        if (stopped == TRUE) {
            return ctx;
        }

        // Continue execution
        return run(instructions=instructions, ctx=ctx);
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
    // @dev Deploys a new starknet contract which functions as a new contract account and
    //      will be mapped to an evm address
    // @param bytes_len: the contract bytecode lenght
    // @param bytes: the contract bytecode
    // @return evm_contract_address The evm address that is mapped to the newly deployed starknet contract address
    // @return starknet_contract_address The newly deployed starknet contract address
    @external
    func deploy_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytes_len: felt, bytes: felt*
    ) -> (evm_contract_address: felt, starknet_contract_address: felt) {
        alloc_locals;
        let (current_salt) = salt.read();
        let (class_hash) = evm_contract_class_hash.read();

        let (local calldata: felt*) = alloc();
        let (kakarot_address) = get_contract_address();

        // Prepare constructor data
        assert [calldata] = kakarot_address;
        assert [calldata + 1] = bytes_len;
        memcpy(dst=calldata + 2, src=bytes, len=bytes_len);

        // Deploy contract account
        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=bytes_len + 2,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE,
        );
        // Increment salt
        salt.write(value=current_salt + 1);
        // Generate EVM_contract address from the new cairo contract
        // TODO: TEMPORARY SOLUTION FOR HACK-LISBON !!!
        let (_, low) = split_felt(contract_address);
        local mock_evm_address = 0xAbdE100700000000000000000000000000000000 + low;
        // Save address of new contracts
        let (reg_address) = registry_address.read();
        IRegistry.set_account_entry(reg_address, contract_address, mock_evm_address);
        return (evm_contract_address=mock_evm_address, starknet_contract_address=contract_address);
    }
}
