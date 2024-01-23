%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.instructions.duplication_operations import DuplicationOperations
from tests.utils.helpers import TestHelpers

func test__exec_dup{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;
    local i: felt;
    local initial_stack_len: felt;
    let (initial_stack_ptr) = alloc();
    let initial_stack = cast(initial_stack_ptr, Uint256*);
    %{
        from itertools import chain
        ids.i = program_input["i"]
        ids.initial_stack_len = len(program_input["initial_stack"])
        segments.write_arg(ids.initial_stack_ptr, list(chain.from_iterable(program_input["initial_stack"])))
    %}

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

    assert [output_ptr] = top.low;
    assert [output_ptr + 1] = top.high;
    return ();
}
