// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.evm import EVM
from kakarot.instructions.duplication_operations import DuplicationOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_dup{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt, stack_len: felt, stack: Uint256*) -> (result: Uint256) {
    let stack_ = TestHelpers.init_stack_with_values(stack_len, stack);
    let (bytecode) = alloc();
    assert [bytecode] = i + 0x7f;
    let evm = TestHelpers.init_context_with_stack(1, bytecode, stack_);

    // When
    let evm = DuplicationOperations.exec_dup(evm);

    // Then
    let (stack_, top) = Stack.peek(evm.stack, 0);
    return ([top],);
}
