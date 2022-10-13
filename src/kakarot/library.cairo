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
from kakarot.instructions import EVMInstructions
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from utils.utils import Helpers

namespace Kakarot {
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        Ownable.initializer(owner);
        return ();
    }

    func execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) {
        alloc_locals;

        // load helper hints
        Helpers.setup_python_defs();

        // generate instructions set
        let instructions: felt* = EVMInstructions.generate_instructions();

        // prepare execution context
        let ctx: model.ExecutionContext* = internal.init_execution_context(code, calldata);

        // start execution
        let ctx: model.ExecutionContext* = run(instructions, ctx);

        return ();
    }

    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        alloc_locals;

        // decode and execute
        let ctx: model.ExecutionContext* = EVMInstructions.decode_and_execute(instructions, ctx);

        // for debugging purpose
        ExecutionContext.dump(ctx);

        // check if execution should be stopped
        let stopped: felt = ExecutionContext.is_stopped(ctx);

        // terminate execution
        if (stopped == TRUE) {
            return ctx;
        }

        // continue execution
        return run(instructions, ctx);
    }
}

namespace internal {
    func init_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) -> model.ExecutionContext* {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();
        let initial_pc = 0;

        let stack: model.Stack* = Stack.init();

        local ctx: model.ExecutionContext* = new model.ExecutionContext(
            code=code,
            code_len=Helpers.get_len(code),
            calldata=calldata,
            program_counter=initial_pc,
            stopped=FALSE,
            return_data=empty_return_data,
            stack=stack,
            );

        return ctx;
    }
}
