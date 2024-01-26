// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy

from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.state import State
from kakarot.instructions.exchange_operations import ExchangeOperations
from tests.utils.helpers import TestHelpers

func test__exec_swap{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;

    local i: felt;
    local initial_stack_len: felt;
    let (initial_stack_ptr: felt*) = alloc();
    let initial_stack = cast(initial_stack_ptr, Uint256*);
    %{
        from itertools import chain
        ids.i = program_input["i"]
        ids.initial_stack_len = len(program_input["initial_stack"])
        segments.write_arg(ids.initial_stack_ptr, list(chain(*program_input["initial_stack"])))
    %}

    let stack = TestHelpers.init_stack_with_values(initial_stack_len, initial_stack);
    let (bytecode) = alloc();
    assert [bytecode] = i + 0x8f;
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);
    let memory = Memory.init();
    let state = State.init();

    // When
    with stack, memory, state {
        let evm = ExchangeOperations.exec_swap(evm);
        let (top) = Stack.peek(0);
        let (swapped) = Stack.peek(i);
    }

    memcpy(output_ptr, cast(top, felt*), 2);
    memcpy(output_ptr + 2, cast(swapped, felt*), 2);
    return ();
}
