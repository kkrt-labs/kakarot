%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.instructions.block_information import BlockInformation
from tests.utils.helpers import TestHelpers

func test__exec_block_information{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    tempvar opcode: felt;
    %{ ids.opcode = program_input["opcode"] %}

    let stack = Stack.init();
    let memory = Memory.init();
    let state = State.init();
    let (bytecode) = alloc();
    assert [bytecode] = opcode;
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);

    // When
    with stack, memory, state {
        let evm = BlockInformation.exec_block_information(evm);
        let (result) = Stack.peek(0);
    }

    // Then
    assert [output_ptr] = result.low;
    assert [output_ptr + 1] = result.high;
    return ();
}
