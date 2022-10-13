// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import Uint256

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

namespace PushOperations {
    // Generic PUSH operation
    // Place i bytes items on stack
    func exec_push_i{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{
            opcode_value =  95 + ids.i
            print(f"0x{opcode_value:02x} - PUSH{ids.i}")
        %}

        // get stack
        let stack: model.Stack* = ctx.stack;

        // read i bytes
        let (ctx, data) = ExecutionContext.read_code(ctx, i);

        // convert to Uint256
        let stack_element: Uint256 = Helpers.bytes_to_uint256(data);
        // push to the stack
        let stack: model.Stack* = Stack.push(stack, stack_element);

        // update context
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func exec_push1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 1);
    }

    func exec_push2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 2);
    }

    func exec_push3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 3);
    }

    func exec_push4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 4);
    }

    func exec_push5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 5);
    }

    func exec_push6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 6);
    }

    func exec_push7{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 7);
    }

    func exec_push8{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 8);
    }

    func exec_push9{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 9);
    }

    func exec_push10{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 10);
    }

    func exec_push11{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 11);
    }

    func exec_push12{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 12);
    }

    func exec_push13{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 13);
    }

    func exec_push14{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 14);
    }

    func exec_push15{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 15);
    }

    func exec_push16{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 16);
    }

    func exec_push17{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 17);
    }

    func exec_push18{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 18);
    }

    func exec_push19{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 19);
    }

    func exec_push20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 20);
    }

    func exec_push21{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 21);
    }

    func exec_push22{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 22);
    }

    func exec_push23{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 23);
    }

    func exec_push24{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 24);
    }

    func exec_push25{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 25);
    }

    func exec_push26{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 26);
    }

    func exec_push27{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 27);
    }

    func exec_push28{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 28);
    }

    func exec_push29{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 29);
    }

    func exec_push30{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 30);
    }

    func exec_push31{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 31);
    }

    func exec_push32{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 32);
    }
}
