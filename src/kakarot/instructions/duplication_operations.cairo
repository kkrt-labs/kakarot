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
from starkware.cairo.common.uint256 import Uint256, uint256_signed_div_rem

// Project dependencies
from openzeppelin.security.safemath.library import SafeUint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Duplication operations opcodes.
// @notice This contract contains the functions to execute for duplication operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace ArithmeticOperations
namespace DuplicationOperations {
    // Define constants.
    const GAS_COST_DUP = 3;

    // @notice Generic DUP operation
    // @dev Duplicate the top i-th stack item to the top of the stack.
    func exec_dup_i{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{
            opcode_value =  127 + ids.i
            print(f"0x{opcode_value:02x} - DUP{ids.i}")
        %}

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Get the value top i-th stack item.
        let element = Stack.peek(stack, i - 1);

        // Duplicate the element to the top of the stack.
        let stack = Stack.push(stack, element);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_DUP);
        return ctx;
    }

    // @notice DUP1 operation
    // @dev Duplicate the top stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 1);
    }

    // @notice DUP2 operation
    // @dev Duplicate the top 2nd stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 2);
    }

    // @notice DUP3 operation
    // @dev Duplicate the top 3rd stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 3);
    }

    // @notice DUP4 operation
    // @dev Duplicate the top 4th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 4);
    }

    // @notice DUP5 operation
    // @dev Duplicate the top 5th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 5);
    }

    // @notice DUP6 operation
    // @dev Duplicate the top 6th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 6);
    }

    // @notice DUP7 operation
    // @dev Duplicate the top 7th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup7{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 7);
    }

    // @notice DUP8 operation
    // @dev Duplicate the top 8th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup8{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 8);
    }

    // @notice DUP9 operation
    // @dev Duplicate the top 9th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup9{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 9);
    }

    // @notice DUP10 operation
    // @dev Duplicate the top 10th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup10{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 10);
    }

    // @notice DUP11 operation
    // @dev Duplicate the top 11th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup11{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 11);
    }

    // @notice DUP12 operation
    // @dev Duplicate the top 12th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup12{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 12);
    }

    // @notice DUP13 operation
    // @dev Duplicate the top 13th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup13{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 13);
    }

    // @notice DUP14 operation
    // @dev Duplicate the top 14th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup14{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 14);
    }

    // @notice DUP15 operation
    // @dev Duplicate the top 15th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup15{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 15);
    }

    // @notice DUP16 operation
    // @dev Duplicate the top 16th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return Updated execution context.
    func exec_dup16{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_dup_i(ctx, 16);
    }
}
