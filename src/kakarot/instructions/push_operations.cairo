// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin

from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack

// @title Push operations opcodes.
// @notice This contract contains the functions to execute for push operations opcodes.
// @author @abdelhamidbakhta
// @custom:namespace PushOperations
namespace PushOperations {
    // Define constants.
    const GAS_COST = 3;

    // @notice Generic PUSH operation
    // @dev Place i bytes items on stack
    func exec_push_i{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, i: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        %{
            opcode_value =  95 + ids.i
            print(f"0x{opcode_value:02x} - PUSH{ids.i}")
        %}

        // Get stack from context.
        let stack: model.Stack* = ctx.stack;

        // Read i bytes.
        let (ctx, data) = ExecutionContext.read_code(ctx, i);

        // Convert to Uint256.
        let stack_element: Uint256 = Helpers.bytes_to_uint256(data);
        // Push to the stack.
        let stack: model.Stack* = Stack.push(stack, stack_element);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST);
        return ctx;
    }

    // @notice PUSH1 operation.
    // @dev Place 1 byte item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 1);
    }

    // @notice PUSH2 operation.
    // @dev Place 2 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 2);
    }

    // @notice PUSH3 operation.
    // @dev Place 3 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 3);
    }

    // @notice PUSH4 operation.
    // @dev Place 4 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 4);
    }

    // @notice PUSH5 operation.
    // @dev Place 5 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 5);
    }

    // @notice PUSH6 operation.
    // @dev Place 6 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 6);
    }

    // @notice PUSH7 operation.
    // @dev Place 7 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push7{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 7);
    }

    // @notice PUSH8 operation.
    // @dev Place 8 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push8{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 8);
    }

    // @notice PUSH9 operation.
    // @dev Place 9 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push9{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 9);
    }

    // @notice PUSH10 operation.
    // @dev Place 10 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push10{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 10);
    }

    // @notice PUSH11 operation.
    // @dev Place 11 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push11{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 11);
    }

    // @notice PUSH12 operation.
    // @dev Place 12 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push12{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 12);
    }

    // @notice PUSH13 operation.
    // @dev Place 13 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push13{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 13);
    }

    // @notice PUSH14 operation.
    // @dev Place 14 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push14{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 14);
    }

    // @notice PUSH15 operation.
    // @dev Place 15 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push15{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 15);
    }

    // @notice PUSH16 operation.
    // @dev Place 16 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push16{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 16);
    }

    // @notice PUSH17 operation.
    // @dev Place 17 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push17{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 17);
    }

    // @notice PUSH18 operation.
    // @dev Place 18 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push18{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 18);
    }

    // @notice PUSH19 operation.
    // @dev Place 19 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push19{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 19);
    }

    // @notice PUSH20 operation.
    // @dev Place 20 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push20{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 20);
    }

    // @notice PUSH21 operation.
    // @dev Place 21 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push21{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 21);
    }

    // @notice PUSH22 operation.
    // @dev Place 22 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push22{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 22);
    }

    // @notice PUSH23 operation.
    // @dev Place 23 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push23{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 23);
    }

    // @notice PUSH24 operation.
    // @dev Place 24 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push24{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 24);
    }

    // @notice PUSH25 operation.
    // @dev Place 25 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push25{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 25);
    }

    // @notice PUSH26 operation.
    // @dev Place 26 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push26{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 26);
    }

    // @notice PUSH27 operation.
    // @dev Place 27 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push27{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 27);
    }

    // @notice PUSH28 operation.
    // @dev Place 28 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push28{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 28);
    }

    // @notice PUSH29 operation.
    // @dev Place 29 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push29{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 29);
    }

    // @notice PUSH30 operation.
    // @dev Place 30 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push30{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 30);
    }

    // @notice PUSH31 operation.
    // @dev Place 31 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push31{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 31);
    }

    // @notice PUSH32 operation.
    // @dev Place 32 bytes item on stack.
    // @custom:since Frontier
    // @custom:group Push Operations
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_push32{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx_ptr: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        return exec_push_i(ctx_ptr, 32);
    }
}
