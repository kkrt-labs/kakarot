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
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations

@view
func __setup__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ();
}

func init_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.ExecutionContext* {
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert [code] = 00;
    tempvar code_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    return ctx;
}

@external
func setup__exec_pc__should_update_after_incrementing{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    %{ given(increment = strategy.felts(rc_bound=True)) %}
    return ();
}

@external
func test__exec_pc__should_update_after_incrementing{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(increment) {
    // Given
    alloc_locals;
    let ctx: model.ExecutionContext* = init_context();
    let ctx = ExecutionContext.increment_program_counter(ctx, increment);

    // When
    let result = MemoryOperations.exec_pc(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = Stack.len(result.stack);
    assert len = 1;
    let index0 = Stack.peek(result.stack, 0);
    assert index0 = Uint256(increment - 1, 0);
    return ();
}
