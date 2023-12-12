// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.state import State
from kakarot.instructions.exchange_operations import ExchangeOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_swap{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt, initial_stack_len: felt, initial_stack: Uint256*) -> (top: Uint256, swapped: Uint256) {
    let stack = TestHelpers.init_stack_with_values(initial_stack_len, initial_stack);
    let (bytecode) = alloc();
    assert [bytecode] = i + 0x8f;
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);
    let memory = Memory.init();

    // When
    with stack, memory, state {
        let evm = ExchangeOperations.exec_swap(evm);
        let (top) = Stack.peek(0);
        let (swapped) = Stack.peek(i);
    }
    return ([top], [swapped]);
}
