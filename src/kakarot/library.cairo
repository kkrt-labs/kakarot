// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from kakarot.model import model
from kakarot.instructions import EVMInstructions
from kakarot.execution_context import ExecutionContext
from kakarot.constants import native_token_address, registry_address
from utils.utils import Helpers

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
// @author @abdelhamidbakhta
// @custom:namespace Kakarot
namespace Kakarot {
    // @notice The constructor of the contract.
    // @param _owner The address of the owner of the contract.
    func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(owner: felt, native_token_address_) {
        Ownable.initializer(owner);
        native_token_address.write(native_token_address_);
        return ();
    }

    // @notice Execute an EVM bytecode.
    // @param _bytecode The bytecode to execute.
    // @param calldata The calldata to pass to the bytecode.
    // @return The pointer to the execution context.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(code: felt*, code_len: felt, calldata: felt*) -> model.ExecutionContext* {
        alloc_locals;

        // Load helper hints
        Helpers.setup_python_defs();

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);

        // Compute intrinsic gas cost and update gas used
        let ctx = ExecutionContext.compute_intrinsic_gas_cost(ctx);

        // Start execution
        let ctx = run(instructions, ctx);

        // For debugging purpose
        ExecutionContext.dump(ctx);

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
        let ctx: model.ExecutionContext* = EVMInstructions.decode_and_execute(instructions, ctx);

        // Check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(ctx);

        // Terminate execution
        if (stopped == TRUE) {
            return ctx;
        }

        // Continue execution
        return run(instructions, ctx);
    }

    // @notice Sets the account registry address.
    // @param account registry address.
    // @return None.
    func set_account_registry{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        registry_address_: felt
    ) {
        Ownable.assert_only_owner();
        registry_address.write(registry_address_);
        return ();
    }

    // @notice Sets the native token address.
    // @param native token address.
    // @return None.
    func set_native_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        native_token_address_: felt
    ) {
        Ownable.assert_only_owner();
        native_token_address.write(native_token_address_);
        return ();
    }
}
