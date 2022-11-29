// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Internal dependencies
from kakarot.model import model
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Exchange operations opcodes.
// @notice This file contains the functions to execute for exchange operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace ExchangeOperations
namespace ExchangeOperations {
    // Define constants.
    const GAS_COST_SWAP = 3;

    // @notice Generic SWAP operation
    // @dev Exchange 1st and i-th stack items
    // @param i The index in the stack to swap with the item at index 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap_i{range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Get the value top i-th stack item.
        let stack = Stack.swap_i(self=stack, i=i + 1);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SWAP);
        return ctx;
    }

    // @notice SWAP1 operation
    // @dev Exchange 1st and 2nd stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap1{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx=ctx, i=1);
        return ctx;
    }

    // @notice SWAP2 operation
    // @dev Exchange 1st and 3rd stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 2);
        return ctx;
    }

    // @notice SWAP3 operation
    // @dev Exchange 1st and 4th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 3);
        return ctx;
    }

    // @notice SWAP4 operation
    // @dev Exchange 1st and 5th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap4{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 4);
        return ctx;
    }

    // @notice SWAP5 operation
    // @dev Exchange 1st and 6th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap5{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 5);
        return ctx;
    }

    // @notice SWAP6 operation
    // @dev Exchange 1st and 7th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap6{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 6);
        return ctx;
    }

    // @notice SWAP7 operation
    // @dev Exchange 1st and 8th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap7{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 7);
        return ctx;
    }

    // @notice SWAP8 operation
    // @dev Exchange 1st and 9th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 8);
        return ctx;
    }

    // @notice SWAP9 operation
    // @dev Exchange 1st and 10th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap9{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 9);
        return ctx;
    }

    // @notice SWAP10 operation
    // @dev Exchange 1st and 11th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap10{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 10);
        return ctx;
    }

    // @notice SWAP11 operation
    // @dev Exchange 1st and 12th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap11{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 11);
        return ctx;
    }

    // @notice SWAP12 operation
    // @dev Exchange 1st and 13th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap12{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 12);
        return ctx;
    }

    // @notice SWAP13 operation
    // @dev Exchange 1st and 14th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap13{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 13);
        return ctx;
    }

    // @notice SWAP14 operation
    // @dev Exchange 1st and 15th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap14{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 14);
        return ctx;
    }

    // @notice SWAP15 operation
    // @dev Exchange 1st and 16th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap15{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 15);
        return ctx;
    }

    // @notice SWAP16 operation
    // @dev Exchange 1st and 17th stack items.
    // @custom:since Frontier
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_swap16{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_swap_i(ctx, 16);
        return ctx;
    }
}
