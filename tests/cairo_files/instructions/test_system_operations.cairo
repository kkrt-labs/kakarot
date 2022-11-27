// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations
from kakarot.constants import Constants
from tests.utils.utils import TestHelpers

@external
func test_exec_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(reason: felt) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(reason, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(stack);

    // When
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    // Then
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(32, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    SystemOperations.exec_revert(ctx);
    return ();
}
