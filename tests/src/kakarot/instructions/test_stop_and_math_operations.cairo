// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.instructions.stop_and_math_operations import StopAndMathOperations
from tests.utils.helpers import TestHelpers

func test__exec_stop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    with stack, memory, state {
        let evm = StopAndMathOperations.exec_stop(evm);
    }

    assert evm.stopped = TRUE;
    assert evm.return_data_len = 0;

    return ();
}

func test__exec_math_operation{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;

    tempvar opcode;
    tempvar initial_stack_len: felt;
    let (initial_stack: felt*) = alloc();
    %{
        ids.opcode = program_input["opcode"];
        ids.initial_stack_len = len(program_input["stack"]);
        segments.write_arg(ids.initial_stack, program_input["stack"])
    %}

    let (bytecode) = alloc();
    assert [bytecode] = opcode;
    let memory = Memory.init();
    let stack = TestHelpers.init_stack_with_values(
        initial_stack_len, cast(initial_stack, Uint256*)
    );
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);
    let state = State.init();

    // When
    with stack, memory, state {
        let evm = StopAndMathOperations.exec_math_operation(evm);
        let (result) = Stack.peek(0);
    }

    // Then
    assert [output_ptr] = result.low;
    assert [output_ptr + 1] = result.high;
    return ();
}
