// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem, assert_not_zero
from starkware.cairo.common.memset import memset

// Local dependencies
from kakarot.precompiles.ec_recover import PrecompileEcRecover
from utils.utils import Helpers
from tests.utils.helpers import TestHelpers

@external
func test_should_fail_when_input_len_is_not_128{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output_len: felt, output: felt*) {
    alloc_locals;
    let (input) = alloc();
    let input_len = 0;
    let result = PrecompileEcRecover.run(PrecompileEcRecover.PRECOMPILE_ADDRESS, input_len, input);
    return (result.output_len, result.output);
}

@external
func test_should_fail_when_recovery_identifier_is_neither_27_nor_28{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> (output_len: felt, output: felt*) {
    alloc_locals;
    let (input) = alloc();
    let input_len = 128;
    memset(input, 1, input_len);
    let result = PrecompileEcRecover.run(PrecompileEcRecover.PRECOMPILE_ADDRESS, input_len, input);
    return (result.output_len, result.output);
}

@external
func test_should_return_evm_address_in_bytes32{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let (input) = alloc();
    let input_len = 128;
    // fill hash
    memset(input, 1, 32);
    // fill v
    memset(input + 32, 0, 31);
    assert [input + 63] = 27;
    // fill r, s
    memset(input + 64, 1, 64);

    let (output_len, output, gas, reverted) = PrecompileEcRecover.run(
        PrecompileEcRecover.PRECOMPILE_ADDRESS, input_len, input
    );
    assert output_len = 32;
    let evm_address = Helpers.bytes32_to_uint256(output);
    assert_not_zero(evm_address.high);
    // eth address is 20 bytes = 16 bytes in low + 4 bytes in high
    // first 12 bytes of high should be 0
    let (leading_bytes, _) = unsigned_div_rem(evm_address.high, 256 ** 4);
    assert leading_bytes = 0;
    return ();
}

@external
func test_should_return_evm_address_for_playground_example{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let (input) = alloc();
    // hash
    assert input[0] = 69;
    assert input[1] = 110;
    assert input[2] = 154;
    assert input[3] = 234;
    assert input[4] = 94;
    assert input[5] = 25;
    assert input[6] = 122;
    assert input[7] = 31;
    assert input[8] = 26;
    assert input[9] = 247;
    assert input[10] = 163;
    assert input[11] = 232;
    assert input[12] = 90;
    assert input[13] = 50;
    assert input[14] = 18;
    assert input[15] = 250;
    assert input[16] = 64;
    assert input[17] = 73;
    assert input[18] = 163;
    assert input[19] = 186;
    assert input[20] = 52;
    assert input[21] = 194;
    assert input[22] = 40;
    assert input[23] = 155;
    assert input[24] = 76;
    assert input[25] = 134;
    assert input[26] = 15;
    assert input[27] = 192;
    assert input[28] = 176;
    assert input[29] = 198;
    assert input[30] = 78;
    assert input[31] = 243;
    // v
    assert input[32] = 0;
    assert input[33] = 0;
    assert input[34] = 0;
    assert input[35] = 0;
    assert input[36] = 0;
    assert input[37] = 0;
    assert input[38] = 0;
    assert input[39] = 0;
    assert input[40] = 0;
    assert input[41] = 0;
    assert input[42] = 0;
    assert input[43] = 0;
    assert input[44] = 0;
    assert input[45] = 0;
    assert input[46] = 0;
    assert input[47] = 0;
    assert input[48] = 0;
    assert input[49] = 0;
    assert input[50] = 0;
    assert input[51] = 0;
    assert input[52] = 0;
    assert input[53] = 0;
    assert input[54] = 0;
    assert input[55] = 0;
    assert input[56] = 0;
    assert input[57] = 0;
    assert input[58] = 0;
    assert input[59] = 0;
    assert input[60] = 0;
    assert input[61] = 0;
    assert input[62] = 0;
    assert input[63] = 28;
    // r
    assert input[64] = 146;
    assert input[65] = 66;
    assert input[66] = 104;
    assert input[67] = 91;
    assert input[68] = 241;
    assert input[69] = 97;
    assert input[70] = 121;
    assert input[71] = 60;
    assert input[72] = 194;
    assert input[73] = 86;
    assert input[74] = 3;
    assert input[75] = 194;
    assert input[76] = 49;
    assert input[77] = 188;
    assert input[78] = 47;
    assert input[79] = 86;
    assert input[80] = 142;
    assert input[81] = 182;
    assert input[82] = 48;
    assert input[83] = 234;
    assert input[84] = 22;
    assert input[85] = 170;
    assert input[86] = 19;
    assert input[87] = 125;
    assert input[88] = 38;
    assert input[89] = 100;
    assert input[90] = 172;
    assert input[91] = 128;
    assert input[92] = 56;
    assert input[93] = 130;
    assert input[94] = 86;
    assert input[95] = 8;
    // s
    assert input[96] = 79;
    assert input[97] = 138;
    assert input[98] = 227;
    assert input[99] = 189;
    assert input[100] = 117;
    assert input[101] = 53;
    assert input[102] = 36;
    assert input[103] = 141;
    assert input[104] = 11;
    assert input[105] = 212;
    assert input[106] = 72;
    assert input[107] = 41;
    assert input[108] = 140;
    assert input[109] = 194;
    assert input[110] = 226;
    assert input[111] = 7;
    assert input[112] = 30;
    assert input[113] = 86;
    assert input[114] = 153;
    assert input[115] = 45;
    assert input[116] = 7;
    assert input[117] = 116;
    assert input[118] = 220;
    assert input[119] = 52;
    assert input[120] = 12;
    assert input[121] = 54;
    assert input[122] = 138;
    assert input[123] = 233;
    assert input[124] = 80;
    assert input[125] = 133;
    assert input[126] = 42;
    assert input[127] = 218;
    let input_len = 128;

    let (output_len, output, gas, reverted) = PrecompileEcRecover.run(
        PrecompileEcRecover.PRECOMPILE_ADDRESS, input_len, input
    );

    assert output_len = 32;

    assert output[0] = 0;
    assert output[1] = 0;
    assert output[2] = 0;
    assert output[3] = 0;
    assert output[4] = 0;
    assert output[5] = 0;
    assert output[6] = 0;
    assert output[7] = 0;
    assert output[8] = 0;
    assert output[9] = 0;
    assert output[10] = 0;
    assert output[11] = 0;
    assert output[12] = 113;
    assert output[13] = 86;
    assert output[14] = 82;
    assert output[15] = 111;
    assert output[16] = 189;
    assert output[17] = 122;
    assert output[18] = 60;
    assert output[19] = 114;
    assert output[20] = 150;
    assert output[21] = 155;
    assert output[22] = 84;
    assert output[23] = 246;
    assert output[24] = 78;
    assert output[25] = 66;
    assert output[26] = 193;
    assert output[27] = 15;
    assert output[28] = 187;
    assert output[29] = 118;
    assert output[30] = 140;
    assert output[31] = 138;
    return ();
}
