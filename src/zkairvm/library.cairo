// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.alloc import alloc

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from zkairvm.model import ExecutionContext, ExecutionContextModel
from zkairvm.instructions import EVMInstructions
from utils.utils import Helpers

namespace Zkairvm {
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
        let (ctx: ExecutionContext) = internal.init_execution_context(code, calldata, verbose=TRUE);

        // start execution
        run(instructions, ctx);

        return ();
    }

    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: felt*, ctx: ExecutionContext
    ) {
        alloc_locals;

        // decode and execute
        EVMInstructions.decode_and_execute(instructions, ctx);

        // for debugging purpose
        ExecutionContextModel.dump(ctx);

        // check if execution should be stopped
        let (stopped) = ExecutionContextModel.is_stopped(ctx);

        // terminate execution
        if (stopped == TRUE) {
            return ();
        }

        // continue execution
        run(instructions, ctx);

        return ();
    }
}

namespace internal {
    func init_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*, verbose: felt
    ) -> (ctx: ExecutionContext) {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();
        let (empty_stopped: felt*) = alloc();
        let initial_pc = 0;
        let (pc: felt*) = alloc();
        assert [pc] = initial_pc;

        let (code_len) = Helpers.get_len(code);
        let ctx: ExecutionContext = ExecutionContext(
            code=code,
            code_len=code_len,
            calldata=calldata,
            pc=pc,
            stopped=empty_stopped,
            return_data=empty_return_data,
            verbose=verbose,
        );
        return (ctx=ctx);
    }

    func dump_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        return ();
    }
}
