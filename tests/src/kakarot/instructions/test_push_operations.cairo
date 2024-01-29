%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memset import memset
from starkware.cairo.common.memcpy import memcpy

from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.instructions.push_operations import PushOperations
from tests.utils.helpers import TestHelpers

func test__exec_push{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    alloc_locals;
    local i: felt;
    %{ ids.i = program_input["i"] %}

    let (bytecode) = alloc();
    assert [bytecode] = i + 0x5f;
    memset(bytecode + 1, 0xff, i);
    let stack = Stack.init();
    let memory = Memory.init();
    let state = State.init();
    let evm = TestHelpers.init_evm_with_bytecode(1 + i, bytecode);

    with stack, memory, state {
        let evm = PushOperations.exec_push(evm);
        let (result) = Stack.peek(0);
    }

    memcpy(output_ptr, cast(result, felt*), 2);
    return ();
}
