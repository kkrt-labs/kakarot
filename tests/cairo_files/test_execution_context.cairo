// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.execution_context import ExecutionContext

@view
func __setup__{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    return ();
}

@external
func test__init__should_return_an_empty_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert [code] = 00;
    tempvar code_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';

    // When
    let result: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);

    // Then
    assert result.code = code;
    assert result.code_len = 1;
    assert result.calldata = calldata;
    assert result.program_counter = 0;
    assert result.stopped = FALSE;
    assert result.stack.raw_len = 0;
    assert result.memory.raw_len = 0;
    assert result.gas_used = 0;
    assert result.gas_limit = 0;  // TODO: Add support for gas limit
    assert result.intrinsic_gas_cost = 0;
    return ();
}

@external
func test__update_program_counter__should_set_pc_to_given_value{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert code[0] = 56;
    assert code[1] = 60;
    assert code[2] = 0x0a;
    assert code[3] = 0x5b;
    assert code[4] = 60;
    assert code[5] = 0x0b;
    tempvar code_len = 6;
    let (calldata) = alloc();
    assert [calldata] = '';

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.update_program_counter(ctx,3);

    // Then
    assert result.program_counter = 3;
    return ();
}

@external
func test__update_program_counter__should_fail__when_given_value_not_in_code_range{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert code[0] = 56;
    assert code[1] = 60;
    assert code[2] = 0x0a;
    assert code[3] = 0x5b;
    assert code[4] = 60;
    assert code[5] = 0x0b;
    tempvar code_len = 6;
    let (calldata) = alloc();
    assert [calldata] = '';

    // When & Then
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.update_program_counter(ctx,6);
    return ();
}

@external
func test__update_program_counter__should_fail__when_given_destination_that_is_not_JUMPDEST{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert code[0] = 56;
    assert code[1] = 60;
    assert code[2] = 0x0a;
    assert code[3] = 0x5b;
    assert code[4] = 60;
    assert code[5] = 0x0b;
    tempvar code_len = 6;
    let (calldata) = alloc();
    assert [calldata] = '';

    // When & Then
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.update_program_counter(ctx,2);
    return ();
}

@external
func test__read_calldata__should_return_parameter_from_calldata{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {

    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0x0c;
    assert calldata[1] = 0x0b;
    assert calldata[2] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let selector = ExecutionContext.read_calldata(ctx,0);
    let param_1 = ExecutionContext.read_calldata(ctx,4);
    let param_2 = ExecutionContext.read_calldata(ctx,4+32);

    // Then
    assert 0x0a = param_2;
    assert 0x0b = param_1;
    assert 0x0c = selector;
    return ();
}

@external
func test__read_calldata__should_fail__when_given_offset_out_of_range{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0x0c;
    assert calldata[1] = 0x0b;
    assert calldata[2] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.read_calldata(ctx,4+32+32);
    return ();
}

@external
func test__read_calldata__should_fail__when_providing_invalid_parameter_offset{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0x0c;
    assert calldata[1] = 0x0b;
    assert calldata[2] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.read_calldata(ctx,4+31);
    return ();
}

@external
func test__read_calldata__should_fail__when_providing_invalid_selector_offset{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0x0c;
    assert calldata[1] = 0x0b;
    assert calldata[2] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let result = ExecutionContext.read_calldata(ctx,3);
    return ();
}
