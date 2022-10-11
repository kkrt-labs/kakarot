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
        ctx: model.ExecutionContext, i: felt
    ) {
        alloc_locals;
        // get stack
        let stack: model.Stack = ExecutionContext.get_stack(ctx);

        // let stack: model.Stack = Stack.init();

        // read i bytes
        let (data) = ExecutionContext.read_code(ctx, i);

        // convert to Uint256
        let (stack_element: Uint256) = Helpers.bytes_to_uint256(data);
        // push to the stack
        let stack: model.Stack = Stack.push(stack, stack_element);

        // update context
        // TODO: compute actual values
        let step: model.ExecutionStep = model.ExecutionStep(pc=0, opcode=0, gas=0, stack=stack);
        ExecutionContext.add_step(ctx, step);

        return ();
    }

    // 0x60 - PUSH1
    // Place 1 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x60 - PUSH1") %}

        exec_push_i(ctx, 1);

        return ();
    }

    // 0x61 - PUSH3
    // Place 2 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x61 - PUSH2") %}

        exec_push_i(ctx, 2);

        return ();
    }

    // 0x62 - PUSH3
    // Place 3 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x62 - PUSH3") %}

        exec_push_i(ctx, 3);

        return ();
    }

    // 0x63 - PUSH4
    // Place 4 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x63 - PUSH4") %}

        exec_push_i(ctx, 4);

        return ();
    }

    // 0x64 - PUSH5
    // Place 5 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x64 - PUSH5") %}

        exec_push_i(ctx, 5);

        return ();
    }

    // 0x65 - PUSH6
    // Place 6 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x65 - PUSH6") %}

        exec_push_i(ctx, 6);

        return ();
    }

    // 0x66 - PUSH7
    // Place 7 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push7{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x66 - PUSH7") %}

        exec_push_i(ctx, 7);

        return ();
    }

    // 0x67 - PUSH8
    // Place 8 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push8{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x67 - PUSH8") %}

        exec_push_i(ctx, 8);

        return ();
    }

    // 0x68 - PUSH9
    // Place 9 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push9{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x68 - PUSH9") %}

        exec_push_i(ctx, 9);

        return ();
    }

    // 0x69 - PUSH10
    // Place 10 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push10{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x69 - PUSH10") %}

        exec_push_i(ctx, 10);

        return ();
    }

    // 0x6A - PUSH11
    // Place 11 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push11{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6A - PUSH11") %}

        exec_push_i(ctx, 11);

        return ();
    }

    // 0x6B - PUSH12
    // Place 12 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push12{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6B - PUSH12") %}

        exec_push_i(ctx, 12);

        return ();
    }

    // 0x6C - PUSH13
    // Place 13 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push13{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6C - PUSH13") %}

        exec_push_i(ctx, 13);

        return ();
    }

    // 0x6D - PUSH14
    // Place 14 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push14{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6D - PUSH14") %}

        exec_push_i(ctx, 14);

        return ();
    }

    // 0x6E - PUSH15
    // Place 15 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push15{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6E - PUSH15") %}

        exec_push_i(ctx, 15);

        return ();
    }

    // 0x6F - PUSH16
    // Place 16 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push16{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x6F - PUSH16") %}

        exec_push_i(ctx, 16);

        return ();
    }

    // 0x70 - PUSH17
    // Place 17 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push17{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x70 - PUSH17") %}

        exec_push_i(ctx, 17);

        return ();
    }

    // 0x71 - PUSH18
    // Place 18 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push18{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x71 - PUSH18") %}

        exec_push_i(ctx, 18);

        return ();
    }

    // 0x72 - PUSH19
    // Place 19 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push19{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x72 - PUSH19") %}

        exec_push_i(ctx, 19);

        return ();
    }

    // 0x73 - PUSH20
    // Place 20 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x73 - PUSH20") %}

        exec_push_i(ctx, 20);

        return ();
    }

    // 0x74 - PUSH21
    // Place 21 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push21{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x74 - PUSH21") %}

        exec_push_i(ctx, 21);

        return ();
    }

    // 0x75 - PUSH22
    // Place 22 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push22{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x75 - PUSH22") %}

        exec_push_i(ctx, 22);

        return ();
    }

    // 0x76 - PUSH23
    // Place 23 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push23{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x76 - PUSH23") %}

        exec_push_i(ctx, 23);

        return ();
    }

    // 0x77 - PUSH24
    // Place 24 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push24{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x77 - PUSH24") %}

        exec_push_i(ctx, 24);

        return ();
    }

    // 0x78 - PUSH25
    // Place 25 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push25{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x77 - PUSH25") %}

        exec_push_i(ctx, 25);

        return ();
    }

    // 0x79 - PUSH26
    // Place 26 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push26{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x79 - PUSH26") %}

        exec_push_i(ctx, 26);

        return ();
    }

    // 0x7A - PUSH27
    // Place 27 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push27{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7A - PUSH27") %}

        exec_push_i(ctx, 27);

        return ();
    }

    // 0x7B - PUSH28
    // Place 28 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push28{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7B - PUSH28") %}

        exec_push_i(ctx, 28);

        return ();
    }

    // 0x7C - PUSH29
    // Place 29 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push29{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7C - PUSH29") %}

        exec_push_i(ctx, 29);

        return ();
    }

    // 0x7D - PUSH30
    // Place 30 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push30{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7D - PUSH30") %}

        exec_push_i(ctx, 30);

        return ();
    }

    // 0x7E - PUSH31
    // Place 31 byte item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push31{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7E - PUSH31") %}

        exec_push_i(ctx, 31);

        return ();
    }

    // 0x7F - PUSH32
    // Place 32 byte (full word) item on stack
    // Since: Frontier
    // Group: Push operations
    func exec_push32{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext
    ) {
        alloc_locals;
        %{ print("0x7F - PUSH32") %}

        exec_push_i(ctx, 32);

        return ();
    }
}
