// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

@external
func test_memory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Helpers.setup_python_defs();

    let memory: model.Memory* = Memory.init();
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(1, 0), offset=0);
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(2, 0), offset=1);
    let memory: model.Memory* = Memory.store(self=memory, element=Uint256(3, 0), offset=2);

    let len = Memory.len(memory);
    assert len = 3;

    Memory.dump(memory);
    return ();
}
