%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.evm import EVM
from kakarot.instructions.system_operations import SystemOperations

from tests.utils.helpers import TestHelpers

func test__auth{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (model.Stack*, model.EVM*) {
    alloc_locals;
    local initial_stack_len;
    local initial_memory_len;
    local invoker_address;
    let (initial_stack_ptr) = alloc();
    let (initial_memory) = alloc();
    let initial_stack = cast(initial_stack_ptr, Uint256*);
    %{
        from itertools import chain
        ids.initial_stack_len = len(program_input["stack"])
        segments.write_arg(ids.initial_stack_ptr, list(chain.from_iterable(program_input["stack"])))
        ids.initial_memory_len = len(program_input["memory"])
        segments.write_arg(ids.initial_memory, program_input["memory"])
        ids.invoker_address = program_input["invoker_address"]
    %}
    let stack = TestHelpers.init_stack_with_values(initial_stack_len, initial_stack);
    let memory = TestHelpers.init_memory_with_values(initial_memory_len, initial_memory);
    let state = State.init();

    let (bytecode) = alloc();
    let evm = TestHelpers.init_evm_at_address(0, bytecode, 0x1234, invoker_address);

    with stack, state, memory {
        let evm = SystemOperations.exec_auth(evm);
    }

    return (stack, evm);
}
