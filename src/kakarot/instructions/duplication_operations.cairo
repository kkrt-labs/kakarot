// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Duplication operations opcodes.
// @notice This file contains the functions to execute for duplication operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace DuplicationOperations
namespace DuplicationOperations {
    // Define constants.
    const GAS_COST_DUP = 3;

    // @notice Generic DUP operation
    // @dev Duplicate the top i-th stack item to the top of the stack.
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup_i{range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Get the value top i-th stack item.
        let (stack,element) = Stack.peek(self=stack, stack_index=i-1);

        // %{ 
        //     import logging
        //     logging.info("DUP INDEX")
        //     logging.info(ids.i)
        //     logging.info("DUP VALUE")
        //     logging.info(ids.element.low)
        // %}

        // Duplicate the element to the top of the stack.
        let stack = Stack.push(self=stack, element=element);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_DUP);
        return ctx;
    }

    // @notice DUP1 operation
    // @dev Duplicate the top stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup1{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=1);
        return ctx;
    }

    // @notice DUP2 operation
    // @dev Duplicate the top 2nd stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=2);
        return ctx;
    }

    // @notice DUP3 operation
    // @dev Duplicate the top 3rd stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=3);
        return ctx;
    }

    // @notice DUP4 operation
    // @dev Duplicate the top 4th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup4{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=4);
        return ctx;
    }

    // @notice DUP5 operation
    // @dev Duplicate the top 5th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup5{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=5);
        return ctx;
    }

    // @notice DUP6 operation
    // @dev Duplicate the top 6th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup6{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=6);
        return ctx;
    }

    // @notice DUP7 operation
    // @dev Duplicate the top 7th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup7{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=7);
        return ctx;
    }

    // @notice DUP8 operation
    // @dev Duplicate the top 8th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=8);
        return ctx;
    }

    // @notice DUP9 operation
    // @dev Duplicate the top 9th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup9{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=9);
        return ctx;
    }

    // @notice DUP10 operation
    // @dev Duplicate the top 10th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup10{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=10);
        return ctx;
    }

    // @notice DUP11 operation
    // @dev Duplicate the top 11th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup11{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=11);
        return ctx;
    }

    // @notice DUP12 operation
    // @dev Duplicate the top 12th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup12{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=12);
        return ctx;
    }

    // @notice DUP13 operation
    // @dev Duplicate the top 13th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup13{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=13);
        return ctx;
    }

    // @notice DUP14 operation
    // @dev Duplicate the top 14th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup14{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=14);
        return ctx;
    }

    // @notice DUP15 operation
    // @dev Duplicate the top 15th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup15{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=15);
        return ctx;
    }

    // @notice DUP16 operation
    // @dev Duplicate the top 16th stack item to the top of the stack.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context.
    // @return Updated execution context.
    func exec_dup16{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_dup_i(ctx=ctx, i=16);
        return ctx;
    }
}
