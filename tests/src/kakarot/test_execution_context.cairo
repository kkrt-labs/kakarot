// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.model import model
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

@external
func test__jump__should_set_pc_to_given_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert bytecode[0] = 56;
    assert bytecode[1] = 60;
    assert bytecode[2] = 0x0a;
    assert bytecode[3] = 0x5b;
    assert bytecode[4] = 60;
    assert bytecode[5] = 0x0b;
    tempvar bytecode_len = 6;

    // When
    let ctx: model.ExecutionContext* = TestHelpers.init_context(bytecode_len, bytecode);
    let result = ExecutionContext.jump(ctx, 3);

    // Then
    assert result.program_counter = 3;
    return ();
}

@external
func test__jump__should_fail__when_given_value_not_in_code_range{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (revert_reason_len: felt, revert_reason: felt*) {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert bytecode[0] = 56;
    assert bytecode[1] = 60;
    assert bytecode[2] = 0x0a;
    assert bytecode[3] = 0x5b;
    assert bytecode[4] = 60;
    assert bytecode[5] = 0x0b;
    tempvar bytecode_len = 6;

    // When & Then
    let ctx: model.ExecutionContext* = TestHelpers.init_context(bytecode_len, bytecode);
    let ctx = ExecutionContext.jump(ctx, 6);
    return (ctx.return_data_len, ctx.return_data);
}

@external
func test__jump__should_fail__when_given_destination_that_is_not_JUMPDEST{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (revert_reason_len: felt, revert_reason: felt*) {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert bytecode[0] = 56;
    assert bytecode[1] = 60;
    assert bytecode[2] = 0x0a;
    assert bytecode[3] = 0x5b;
    assert bytecode[4] = 60;
    assert bytecode[5] = 0x0b;
    tempvar bytecode_len = 6;

    // When & Then
    let ctx: model.ExecutionContext* = TestHelpers.init_context(bytecode_len, bytecode);
    let ctx = ExecutionContext.jump(ctx, 2);
    return (ctx.return_data_len, ctx.return_data);
}
