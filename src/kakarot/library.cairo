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
    }(owner: felt) {
        Ownable.initializer(owner);
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
    }(code: felt*, calldata: felt*) -> model.ExecutionContext* {
        alloc_locals;

        // Load helper hints
        Helpers.setup_python_defs();

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = ExecutionContext.init(code, calldata);

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
}
