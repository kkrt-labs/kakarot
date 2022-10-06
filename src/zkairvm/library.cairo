// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.alloc import alloc

// OpenZeppelin dependencies
from openzeppelin.access.ownable.library import Ownable

// Internal dependencies
from zkairvm.model import ExecutionContext
from zkairvm.instructions import EVMInstructions
from tests.utils import test_utils

namespace Zkairvm {
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        Ownable.initializer(owner);
        return ();
    }

    func execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) {
        alloc_locals;

        // TODO: remove when stable
        // for debugging purpose
        test_utils.setup_python_defs();

        // generate instructions set
        let instructions: codeoffset* = EVMInstructions.generate_instructions();

        let (ctx: ExecutionContext) = internal.init_execution_context(code, calldata, verbose=TRUE);
        run(instructions, ctx);
        return ();
    }

    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        instructions: codeoffset*, ctx: ExecutionContext
    ) {
        alloc_locals;
        // for debugging purpose
        internal.debug_execution_context(ctx);

        // logging
        if (ctx.verbose == TRUE) {
            // internal.dump_execution_context(ctx);
        }

        // decode and execute
        EVMInstructions.decode_and_execute(instructions, ctx);

        // terminate execution
        if (ctx.stopped == TRUE) {
            // return ();
        }

        // run(instructions, ctx);

        return ();
    }
}

namespace internal {
    func init_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*, verbose: felt
    ) -> (ctx: ExecutionContext) {
        alloc_locals;
        let (empty_return_data: felt*) = alloc();
        let ctx: ExecutionContext = ExecutionContext(
            code=code,
            calldata=calldata,
            pc=0,
            stopped=FALSE,
            return_data=empty_return_data,
            verbose=verbose,
        );
        return (ctx=ctx);
    }

    func dump_execution_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        %{ print(f"pc: {ids.ctx.pc}") %}
        return ();
    }

    func debug_execution_context(ctx: ExecutionContext) {
        %{
            code = cairo_bytes_to_hex(ids.ctx.code)
            calldata = cairo_bytes_to_hex(ids.ctx.calldata)
            return_data = cairo_bytes_to_hex(ids.ctx.return_data)
            json = {
                "pc": f"{ids.ctx.pc}",
                "stopped": f"{ids.ctx.stopped}",
                "code": f"{code}",
                "calldata": f"{calldata}",
                "return_data": f"{return_data}",
            }
            post_debug(json)
        %}
        return ();
    }
}
