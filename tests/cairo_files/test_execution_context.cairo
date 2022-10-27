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
    assert result.memory.bytes_len = 0;
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
    let result = ExecutionContext.update_program_counter(ctx, 3);

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
    let result = ExecutionContext.update_program_counter(ctx, 6);
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
    let result = ExecutionContext.update_program_counter(ctx, 2);
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
    assert calldata[0] = 0x00;
    assert calldata[1] = 0x00;
    assert calldata[2] = 0x00;
    assert calldata[3] = 0x00;
    assert calldata[4] = 0x00;
    assert calldata[5] = 0x00;
    assert calldata[6] = 0x00;
    assert calldata[7] = 0x00;
    assert calldata[8] = 0x00;
    assert calldata[9] = 0x00;
    assert calldata[10] = 0x00;
    assert calldata[11] = 0x00;
    assert calldata[12] = 0x00;
    assert calldata[13] = 0x00;
    assert calldata[14] = 0x00;
    assert calldata[15] = 0x00;
    assert calldata[16] = 0x00;
    assert calldata[17] = 0x00;
    assert calldata[18] = 0x00;
    assert calldata[19] = 0x00;
    assert calldata[20] = 0x00;
    assert calldata[21] = 0x00;
    assert calldata[22] = 0x00;
    assert calldata[23] = 0x00;
    assert calldata[24] = 0x00;
    assert calldata[25] = 0x00;
    assert calldata[26] = 0x00;
    assert calldata[27] = 0x00;
    assert calldata[28] = 0x00;
    assert calldata[29] = 0x00;
    assert calldata[30] = 0x00;
    assert calldata[31] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let (local entire_memory: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,0,32,entire_memory);
    let (local half_padded: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,16,32,half_padded);
    let (local full_padded: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,31,32,full_padded);
   
    // Then
    assert Uint256(0x0a,0) = entire_memory[0];
    assert Uint256(0x0,0xa) = half_padded[0]; 
    assert Uint256(0x0,0xa000000000000000000000000000000) = full_padded[0];
    return ();
}

@external
func test__read_calldata__should_return_parameter_from_calldata_extended{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0x00;
    assert calldata[1] = 0x00;
    assert calldata[2] = 0x00;
    assert calldata[3] = 0x00;
    assert calldata[4] = 0x00;
    assert calldata[5] = 0x00;
    assert calldata[6] = 0x00;
    assert calldata[7] = 0x00;
    assert calldata[8] = 0x00;
    assert calldata[9] = 0x00;
    assert calldata[10] = 0x00;
    assert calldata[11] = 0x00;
    assert calldata[12] = 0x00;
    assert calldata[13] = 0x00;
    assert calldata[14] = 0x00;
    assert calldata[15] = 0x00;
    assert calldata[16] = 0x00;
    assert calldata[17] = 0x0a;
    assert calldata[18] = 0x00;
    assert calldata[19] = 0x00;
    assert calldata[20] = 0x00;
    assert calldata[21] = 0x00;
    assert calldata[22] = 0x00;
    assert calldata[23] = 0x00;
    assert calldata[24] = 0x00;
    assert calldata[25] = 0x00;
    assert calldata[26] = 0x00;
    assert calldata[27] = 0x00;
    assert calldata[28] = 0x00;
    assert calldata[29] = 0x00;
    assert calldata[30] = 0x00;
    assert calldata[31] = 0x0a;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let (local entire_memory: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,0,32,entire_memory);
    let (local half_padded: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,16,32,half_padded);
    let (local full_padded: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,31,32,full_padded);
   
    // Then
    assert Uint256(0x0a000000000000000000000000000a,0) = entire_memory[0];
    assert Uint256(0x0,0x0a000000000000000000000000000a) = half_padded[0]; 
    assert Uint256(0x0,0xa000000000000000000000000000000) = full_padded[0];
    return ();
}

@external
func test__read_calldata__should_return_variable_byte_length{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    tempvar code_len = 0;
    let (calldata) = alloc();
    assert calldata[0] = 0xFF;
    assert calldata[1] = 0xFF;
    assert calldata[2] = 0xFF;
    assert calldata[3] = 0xFF;
    assert calldata[4] = 0xFF;
    assert calldata[5] = 0xFF;
    assert calldata[6] = 0xFF;
    assert calldata[7] = 0xFF;
    assert calldata[8] = 0xFF;
    assert calldata[9] = 0xFF;
    assert calldata[10] = 0xFF;
    assert calldata[11] = 0xFF;
    assert calldata[12] = 0xFF;
    assert calldata[13] = 0xFF;
    assert calldata[14] = 0xFF;
    assert calldata[15] = 0xFF;
    assert calldata[16] = 0xFF;
    assert calldata[17] = 0xFF;
    assert calldata[18] = 0xFF;
    assert calldata[19] = 0xFF;
    assert calldata[20] = 0xFF;
    assert calldata[21] = 0xFF;
    assert calldata[22] = 0xFF;
    assert calldata[23] = 0xFF;
    assert calldata[24] = 0xFF;
    assert calldata[25] = 0xFF;
    assert calldata[26] = 0xFF;
    assert calldata[27] = 0xFF;
    assert calldata[28] = 0xFF;
    assert calldata[29] = 0xFF;
    assert calldata[30] = 0xFF;
    assert calldata[31] = 0xFF;

    // When
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let (local entire_memory: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,31,8,entire_memory);
   
    // Then
    assert Uint256(0xFF00000000000000,0x0) = entire_memory[0];
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
    assert calldata[0] = 0x00;
    assert calldata[1] = 0x00;
    assert calldata[2] = 0x00;
    assert calldata[3] = 0x00;
    assert calldata[4] = 0x00;
    assert calldata[5] = 0x00;
    assert calldata[6] = 0x00;
    assert calldata[7] = 0x00;
    assert calldata[8] = 0x00;
    assert calldata[9] = 0x00;
    assert calldata[10] = 0x00;
    assert calldata[11] = 0x00;
    assert calldata[12] = 0x00;
    assert calldata[13] = 0x00;
    assert calldata[14] = 0x00;
    assert calldata[15] = 0x00;
    assert calldata[16] = 0x00;
    assert calldata[17] = 0x00;
    assert calldata[18] = 0x00;
    assert calldata[19] = 0x00;
    assert calldata[20] = 0x00;
    assert calldata[21] = 0x00;
    assert calldata[22] = 0x00;
    assert calldata[23] = 0x00;
    assert calldata[24] = 0x00;
    assert calldata[25] = 0x00;
    assert calldata[26] = 0x00;
    assert calldata[27] = 0x00;
    assert calldata[28] = 0x00;
    assert calldata[29] = 0x00;
    assert calldata[30] = 0x00;
    assert calldata[31] = 0x0a;

    // When & Then
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, code_len, calldata);
    let (local entire_memory: Uint256*) = alloc();
    ExecutionContext.read_calldata(ctx,33,32,entire_memory);
    return ();
}