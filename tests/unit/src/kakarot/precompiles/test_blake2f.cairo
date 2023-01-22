// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.blake2f import PrecompileBlake2f
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test_should_fail_when_input_is_not_213{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 212;

    PrecompileBlake2f.run(input_len, input);
    return ();
}

@external
func test_should_fail_when_flag_is_not_0_or_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (input) = alloc();
    let input_len = 213;
    TestHelpers.array_fill(input, input_len - 1, 0x00);
    assert input[212] = 0x02;

    PrecompileBlake2f.run(input_len, input);
    return ();
}

@external
func test_should_return_blake2f_compression{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(rounds: felt, h_len: felt, h: felt*, m_len: felt, m: felt*, t0: felt, t1: felt, f: felt) -> (
    output_len: felt, output: felt*
) {
    alloc_locals;
    let (local input: felt*) = alloc();
    Helpers.split_word(rounds, 4, input);
    Helpers.fill_array(h_len, h, input + 4);
    Helpers.fill_array(m_len, m, input + 68);
    Helpers.split_word_little(t0, 8, input + 196);
    Helpers.split_word_little(t1, 8, input + 196 + 8);
    assert input[212] = f;

    let (output_len, output, _) = PrecompileBlake2f.run(213, input);

    return (output_len=output_len, output=output);
}

@external
func test_should_return_blake2f_compression_with_flag_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (input: felt*) = alloc();
    let input_len = 213;

    assert input[0] = 0x00;
    assert input[1] = 0x00;
    assert input[2] = 0x00;
    assert input[3] = 0x0c;
    assert input[4] = 0x48;
    assert input[5] = 0xc9;
    assert input[6] = 0xbd;
    assert input[7] = 0xf2;
    assert input[8] = 0x67;
    assert input[9] = 0xe6;
    assert input[10] = 0x09;
    assert input[11] = 0x6a;
    assert input[12] = 0x3b;
    assert input[13] = 0xa7;
    assert input[14] = 0xca;
    assert input[15] = 0x84;
    assert input[16] = 0x85;
    assert input[17] = 0xae;
    assert input[18] = 0x67;
    assert input[19] = 0xbb;
    assert input[20] = 0x2b;
    assert input[21] = 0xf8;
    assert input[22] = 0x94;
    assert input[23] = 0xfe;
    assert input[24] = 0x72;
    assert input[25] = 0xf3;
    assert input[26] = 0x6e;
    assert input[27] = 0x3c;
    assert input[28] = 0xf1;
    assert input[29] = 0x36;
    assert input[30] = 0x1d;
    assert input[31] = 0x5f;
    assert input[32] = 0x3a;
    assert input[33] = 0xf5;
    assert input[34] = 0x4f;
    assert input[35] = 0xa5;
    assert input[36] = 0xd1;
    assert input[37] = 0x82;
    assert input[38] = 0xe6;
    assert input[39] = 0xad;
    assert input[40] = 0x7f;
    assert input[41] = 0x52;
    assert input[42] = 0x0e;
    assert input[43] = 0x51;
    assert input[44] = 0x1f;
    assert input[45] = 0x6c;
    assert input[46] = 0x3e;
    assert input[47] = 0x2b;
    assert input[48] = 0x8c;
    assert input[49] = 0x68;
    assert input[50] = 0x05;
    assert input[51] = 0x9b;
    assert input[52] = 0x6b;
    assert input[53] = 0xbd;
    assert input[54] = 0x41;
    assert input[55] = 0xfb;
    assert input[56] = 0xab;
    assert input[57] = 0xd9;
    assert input[58] = 0x83;
    assert input[59] = 0x1f;
    assert input[60] = 0x79;
    assert input[61] = 0x21;
    assert input[62] = 0x7e;
    assert input[63] = 0x13;
    assert input[64] = 0x19;
    assert input[65] = 0xcd;
    assert input[66] = 0xe0;
    assert input[67] = 0x5b;
    assert input[68] = 0x61;
    assert input[69] = 0x62;
    assert input[70] = 0x63;
    TestHelpers.array_fill(input + 71, 125, 0x00);
    assert input[196] = 0x03;
    TestHelpers.array_fill(input + 197, 15, 0x00);
    assert input[212] = 0x01;

    // When
    let (output_len, output, gas) = PrecompileBlake2f.run(input_len, input);

    // Then
    assert output_len = 64;
    assert gas = 12;
    assert output[0] = 0xba;
    assert output[1] = 0x80;
    assert output[2] = 0xa5;
    assert output[3] = 0x3f;
    assert output[4] = 0x98;
    assert output[5] = 0x1c;
    assert output[6] = 0x4d;
    assert output[7] = 0x0d;
    assert output[8] = 0x6a;
    assert output[9] = 0x27;
    assert output[10] = 0x97;
    assert output[11] = 0xb6;
    assert output[12] = 0x9f;
    assert output[13] = 0x12;
    assert output[14] = 0xf6;
    assert output[15] = 0xe9;
    assert output[16] = 0x4c;
    assert output[17] = 0x21;
    assert output[18] = 0x2f;
    assert output[19] = 0x14;
    assert output[20] = 0x68;
    assert output[21] = 0x5a;
    assert output[22] = 0xc4;
    assert output[23] = 0xb7;
    assert output[24] = 0x4b;
    assert output[25] = 0x12;
    assert output[26] = 0xbb;
    assert output[27] = 0x6f;
    assert output[28] = 0xdb;
    assert output[29] = 0xff;
    assert output[30] = 0xa2;
    assert output[31] = 0xd1;
    assert output[32] = 0x7d;
    assert output[33] = 0x87;
    assert output[34] = 0xc5;
    assert output[35] = 0x39;
    assert output[36] = 0x2a;
    assert output[37] = 0xab;
    assert output[38] = 0x79;
    assert output[39] = 0x2d;
    assert output[40] = 0xc2;
    assert output[41] = 0x52;
    assert output[42] = 0xd5;
    assert output[43] = 0xde;
    assert output[44] = 0x45;
    assert output[45] = 0x33;
    assert output[46] = 0xcc;
    assert output[47] = 0x95;
    assert output[48] = 0x18;
    assert output[49] = 0xd3;
    assert output[50] = 0x8a;
    assert output[51] = 0xa8;
    assert output[52] = 0xdb;
    assert output[53] = 0xf1;
    assert output[54] = 0x92;
    assert output[55] = 0x5a;
    assert output[56] = 0xb9;
    assert output[57] = 0x23;
    assert output[58] = 0x86;
    assert output[59] = 0xed;
    assert output[60] = 0xd4;
    assert output[61] = 0x00;
    assert output[62] = 0x99;
    assert output[63] = 0x23;
    return ();
}

@external
func test_should_return_blake2f_compression_with_flag_0{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let (input: felt*) = alloc();
    let input_len = 213;

    assert input[0] = 0x00;
    assert input[1] = 0x00;
    assert input[2] = 0x00;
    assert input[3] = 0x0c;
    assert input[4] = 0x48;
    assert input[5] = 0xc9;
    assert input[6] = 0xbd;
    assert input[7] = 0xf2;
    assert input[8] = 0x67;
    assert input[9] = 0xe6;
    assert input[10] = 0x09;
    assert input[11] = 0x6a;
    assert input[12] = 0x3b;
    assert input[13] = 0xa7;
    assert input[14] = 0xca;
    assert input[15] = 0x84;
    assert input[16] = 0x85;
    assert input[17] = 0xae;
    assert input[18] = 0x67;
    assert input[19] = 0xbb;
    assert input[20] = 0x2b;
    assert input[21] = 0xf8;
    assert input[22] = 0x94;
    assert input[23] = 0xfe;
    assert input[24] = 0x72;
    assert input[25] = 0xf3;
    assert input[26] = 0x6e;
    assert input[27] = 0x3c;
    assert input[28] = 0xf1;
    assert input[29] = 0x36;
    assert input[30] = 0x1d;
    assert input[31] = 0x5f;
    assert input[32] = 0x3a;
    assert input[33] = 0xf5;
    assert input[34] = 0x4f;
    assert input[35] = 0xa5;
    assert input[36] = 0xd1;
    assert input[37] = 0x82;
    assert input[38] = 0xe6;
    assert input[39] = 0xad;
    assert input[40] = 0x7f;
    assert input[41] = 0x52;
    assert input[42] = 0x0e;
    assert input[43] = 0x51;
    assert input[44] = 0x1f;
    assert input[45] = 0x6c;
    assert input[46] = 0x3e;
    assert input[47] = 0x2b;
    assert input[48] = 0x8c;
    assert input[49] = 0x68;
    assert input[50] = 0x05;
    assert input[51] = 0x9b;
    assert input[52] = 0x6b;
    assert input[53] = 0xbd;
    assert input[54] = 0x41;
    assert input[55] = 0xfb;
    assert input[56] = 0xab;
    assert input[57] = 0xd9;
    assert input[58] = 0x83;
    assert input[59] = 0x1f;
    assert input[60] = 0x79;
    assert input[61] = 0x21;
    assert input[62] = 0x7e;
    assert input[63] = 0x13;
    assert input[64] = 0x19;
    assert input[65] = 0xcd;
    assert input[66] = 0xe0;
    assert input[67] = 0x5b;
    assert input[68] = 0x61;
    assert input[69] = 0x62;
    assert input[70] = 0x63;
    TestHelpers.array_fill(input + 71, 125, 0x00);
    assert input[196] = 0x03;
    TestHelpers.array_fill(input + 197, 16, 0x00);

    // When
    let (output_len, output, gas) = PrecompileBlake2f.run(input_len, input);

    // Then
    assert output_len = 64;
    assert gas = 12;
    assert output[0] = 0x75;
    assert output[1] = 0xab;
    assert output[2] = 0x69;
    assert output[3] = 0xd3;
    assert output[4] = 0x19;
    assert output[5] = 0x0a;
    assert output[6] = 0x56;
    assert output[7] = 0x2c;
    assert output[8] = 0x51;
    assert output[9] = 0xae;
    assert output[10] = 0xf8;
    assert output[11] = 0xd8;
    assert output[12] = 0x8f;
    assert output[13] = 0x1c;
    assert output[14] = 0x27;
    assert output[15] = 0x75;
    assert output[16] = 0x87;
    assert output[17] = 0x69;
    assert output[18] = 0x44;
    assert output[19] = 0x40;
    assert output[20] = 0x72;
    assert output[21] = 0x70;
    assert output[22] = 0xc4;
    assert output[23] = 0x2c;
    assert output[24] = 0x98;
    assert output[25] = 0x44;
    assert output[26] = 0x25;
    assert output[27] = 0x2c;
    assert output[28] = 0x26;
    assert output[29] = 0xd2;
    assert output[30] = 0x87;
    assert output[31] = 0x52;
    assert output[32] = 0x98;
    assert output[33] = 0x74;
    assert output[34] = 0x3e;
    assert output[35] = 0x7f;
    assert output[36] = 0x6d;
    assert output[37] = 0x5e;
    assert output[38] = 0xa2;
    assert output[39] = 0xf2;
    assert output[40] = 0xd3;
    assert output[41] = 0xe8;
    assert output[42] = 0xd2;
    assert output[43] = 0x26;
    assert output[44] = 0x03;
    assert output[45] = 0x9c;
    assert output[46] = 0xd3;
    assert output[47] = 0x1b;
    assert output[48] = 0x4e;
    assert output[49] = 0x42;
    assert output[50] = 0x6a;
    assert output[51] = 0xc4;
    assert output[52] = 0xf2;
    assert output[53] = 0xd3;
    assert output[54] = 0xd6;
    assert output[55] = 0x66;
    assert output[56] = 0xa6;
    assert output[57] = 0x10;
    assert output[58] = 0xc2;
    assert output[59] = 0x11;
    assert output[60] = 0x6f;
    assert output[61] = 0xde;
    assert output[62] = 0x47;
    assert output[63] = 0x35;
    return ();
}
