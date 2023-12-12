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
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.instructions.duplication_operations import DuplicationOperations
from tests.utils.helpers import TestHelpers

@external
func test__exec_dup{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(i: felt, initial_stack_len: felt, initial_stack: Uint256*) -> (result: Uint256) {
    let stack = TestHelpers.init_stack_with_values(initial_stack_len, initial_stack);
    let memory = Memory.init();
    let state = State.init();
    let (bytecode) = alloc();
    assert [bytecode] = i + 0x7f;
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);

    with stack, memory, state {
        let evm = DuplicationOperations.exec_dup(evm);
        let (top) = Stack.peek(0);
    }

    return ([top],);
}
