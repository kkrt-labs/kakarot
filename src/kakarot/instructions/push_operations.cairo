// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.bool import FALSE, TRUE

// Internal dependencies
from kakarot.model import model
from kakarot.constants import Constants
from kakarot.errors import Errors
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Push operations opcodes.
// @notice This file contains the functions to execute for push operations opcodes.
namespace PushOperations {
    // Define constants.
    // Gascost for push0 is 2; all else are 3
    const BASE_GAS_COST = 2;

    // @notice Generic PUSH operation
    // @dev Place i bytes items on stack
    // @param ctx The pointer to the execution context
    // @param i The number of byte items to push on to the stack
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push_i{range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;

        if (ctx.stack.size == Constants.STACK_MAX_DEPTH) {
            let (revert_reason_len, revert_reason) = Errors.stackOverflow();
            let ctx = ExecutionContext.stop(ctx, revert_reason_len, revert_reason, TRUE);
            return ctx;
        }

        let pc = ctx.program_counter;
        // Copy code slice
        let out_of_bounds = is_le(ctx.call_context.bytecode_len, pc + i);
        local len = (1 - out_of_bounds) * i + out_of_bounds * (ctx.call_context.bytecode_len - pc);

        let stack_element = Helpers.bytes_i_to_uint256(ctx.call_context.bytecode + pc, len);
        tempvar item = new Uint256(stack_element.low, stack_element.high);
        let stack = Stack.push(ctx.stack, item);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let i_is_not_zero = is_not_zero(i);
        let ctx = ExecutionContext.increment_gas_used(ctx, BASE_GAS_COST + i_is_not_zero);
        // Move program counter
        let ctx = ExecutionContext.increment_program_counter(ctx, len);

        return ctx;
    }

    // @notice PUSH0 operation.
    // @dev Place 0 byte item on stack.
    // @custom:since Shanghai
    // @custom:group Push Operations
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push0{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 0);
        return ctx;
    }

    // @notice PUSH1 operation.
    // @dev Place 1 byte item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push1{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 1);
        return ctx;
    }

    // @notice PUSH2 operation.
    // @dev Place 2 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 2);
        return ctx;
    }

    // @notice PUSH3 operation.
    // @dev Place 3 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push3{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 3);
        return ctx;
    }

    // @notice PUSH4 operation.
    // @dev Place 4 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push4{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 4);
        return ctx;
    }

    // @notice PUSH5 operation.
    // @dev Place 5 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push5{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 5);
        return ctx;
    }

    // @notice PUSH6 operation.
    // @dev Place 6 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push6{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 6);
        return ctx;
    }

    // @notice PUSH7 operation.
    // @dev Place 7 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push7{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 7);
        return ctx;
    }

    // @notice PUSH8 operation.
    // @dev Place 8 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push8{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 8);
        return ctx;
    }

    // @notice PUSH9 operation.
    // @dev Place 9 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push9{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 9);
        return ctx;
    }

    // @notice PUSH10 operation.
    // @dev Place 10 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push10{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 10);
        return ctx;
    }

    // @notice PUSH11 operation.
    // @dev Place 11 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push11{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 11);
        return ctx;
    }

    // @notice PUSH12 operation.
    // @dev Place 12 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push12{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 12);
        return ctx;
    }

    // @notice PUSH13 operation.
    // @dev Place 13 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push13{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 13);
        return ctx;
    }

    // @notice PUSH14 operation.
    // @dev Place 14 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push14{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 14);
        return ctx;
    }

    // @notice PUSH15 operation.
    // @dev Place 15 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push15{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 15);
        return ctx;
    }

    // @notice PUSH16 operation.
    // @dev Place 16 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push16{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 16);
        return ctx;
    }

    // @notice PUSH17 operation.
    // @dev Place 17 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push17{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 17);
        return ctx;
    }

    // @notice PUSH18 operation.
    // @dev Place 18 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push18{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 18);
        return ctx;
    }

    // @notice PUSH19 operation.
    // @dev Place 19 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push19{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 19);
        return ctx;
    }

    // @notice PUSH20 operation.
    // @dev Place 20 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push20{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 20);
        return ctx;
    }

    // @notice PUSH21 operation.
    // @dev Place 21 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push21{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 21);
        return ctx;
    }

    // @notice PUSH22 operation.
    // @dev Place 22 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push22{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 22);
        return ctx;
    }

    // @notice PUSH23 operation.
    // @dev Place 23 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push23{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 23);
        return ctx;
    }

    // @notice PUSH24 operation.
    // @dev Place 24 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push24{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 24);
        return ctx;
    }

    // @notice PUSH25 operation.
    // @dev Place 25 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push25{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 25);
        return ctx;
    }

    // @notice PUSH26 operation.
    // @dev Place 26 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push26{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 26);
        return ctx;
    }

    // @notice PUSH27 operation.
    // @dev Place 27 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push27{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 27);
        return ctx;
    }

    // @notice PUSH28 operation.
    // @dev Place 28 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push28{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 28);
        return ctx;
    }

    // @notice PUSH29 operation.
    // @dev Place 29 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push29{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 29);
        return ctx;
    }

    // @notice PUSH30 operation.
    // @dev Place 30 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push30{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 30);
        return ctx;
    }

    // @notice PUSH31 operation.
    // @dev Place 31 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push31{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 31);
        return ctx;
    }

    // @notice PUSH32 operation.
    // @dev Place 32 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_push32{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) -> model.ExecutionContext* {
        let ctx = exec_push_i(ctx_ptr, 32);
        return ctx;
    }
}
