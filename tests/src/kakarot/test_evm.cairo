%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.memcpy import memcpy

from kakarot.stack import Stack
from kakarot.interpreter import Interpreter
from kakarot.memory import Memory
from kakarot.state import State
from kakarot.model import model
from tests.utils.helpers import TestHelpers

func test__unknown_opcode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.EVM* {
    alloc_locals;
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    with stack, memory, state {
        let evm = Interpreter.unknown_opcode(evm);
    }

    return evm;
}
