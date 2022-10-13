// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.alloc import alloc

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from kakarot.model import model
from kakarot.constants import Constants
from kakarot.instructions import EVMInstructions
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from utils.utils import Helpers

// @title Kakarot main library file.
// @notice This file contains the core EVM execution logic.
// @author @abdelhamidbakhta
// @custom:namespace Kakarot
namespace Kakarot {
    // @notice The constructor of the contract.
    // @param _owner The address of the owner of the contract.
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        Ownable.initializer(owner);
        return ();
    }

    // @notice Execute an EVM bytecode.
    // @param _bytecode The bytecode to execute.
    // @param calldata The calldata to pass to the bytecode.
    // @return The pointer to the execution context.
    func execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Load helper hints
        Helpers.setup_python_defs();

        // Generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // Prepare execution context
        let ctx: model.ExecutionContext* = internal.init_execution_context(code, calldata);

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
    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
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

namespace internal {
    func init_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();

        // Define initial program counter
        let initial_pc = 0;
        // Start with intrisic gas cost
        let gas_used = Constants.TRANSACTION_INTRINSIC_GAS_COST;
        // TODO: Add support for gas limit
        let gas_limit = 0;

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        return new model.ExecutionContext(
            code=code,
            code_len=Helpers.get_len(code),
            calldata=calldata,
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            stack=stack,
            memory=memory,
            gas_used=gas_used,
            gas_limit=gas_limit
            );
    }
}
