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
from tests.utils import test_utils

namespace Zkairvm {
    func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
        Ownable.initializer(owner);
        return ();
    }

    func execute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        code: felt*, calldata: felt*
    ) {
        // TODO: remove when stable
        // for debugging purpose
        test_utils.setup_python_defs();
        let (ctx: ExecutionContext) = internal.init_execution_context(code, calldata, verbose=TRUE);
        run(ctx);
        return ();
    }

    func run{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: ExecutionContext
    ) {
        alloc_locals;
        // for debugging purpose
        internal.debug_execution_context(ctx);

        // logging
        if (ctx.verbose == TRUE) {
            // internal.dump_execution_context(ctx);
        }

        // terminate execution
        if (ctx.stopped == TRUE) {
            // return ();
        }

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
            code = [memory[ids.ctx.code + i] for i in range(4)]
            json = {
                "code": f"{code}"
            }
            post_debug(json)
        %}
        return ();
    }
}
