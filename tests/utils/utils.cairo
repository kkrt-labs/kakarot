// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.cairo.common.math import split_felt

// Internal dependencies
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.model import model
from utils.utils import Helpers
from tests.utils.model import EVMTestCase

namespace test_utils {
    // @notice Assert that the value at the top of the stack is equal to the expected value.
    // @param ctx The pointer to the execution context.
    // @param expected_value The expected value.
    func assert_top_stack{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, expected_value: Uint256) {
        alloc_locals;
        let (stack, actual) = Stack.pop(ctx.stack);
        let (are_equal) = uint256_eq(actual, expected_value);
        assert are_equal = TRUE;
        return ();
    }

    // @notice Assert that the value at the top of the stack is equal to the expected value.
    // @param ctx The pointer to the execution context.
    // @param expected_value The expected value.
    func assert_top_memory{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, expected_value: Uint256) {
        alloc_locals;
        let actual = Memory.load(ctx.memory, ctx.memory.end_index - 32);
        let (are_equal) = uint256_eq(actual, expected_value);
        assert are_equal = TRUE;
        return ();
    }
}
