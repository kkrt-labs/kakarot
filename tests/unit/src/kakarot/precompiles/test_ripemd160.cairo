// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test__ripemd160_1{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // message: "a"
    // expected hashcode: 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe
    alloc_locals;
    let (local msg: felt*) = alloc();
    assert [msg] = 97;
    let (_, hash, _) = PrecompileRIPEMD160.run(1, msg);

    assert hash[0] = 0x0b;
    assert hash[1] = 0xdc;
    assert hash[2] = 0x9d;
    assert hash[3] = 0x2d;
    assert hash[4] = 0x25;
    assert hash[5] = 0x6b;
    assert hash[6] = 0x3e;
    assert hash[7] = 0xe9;
    assert hash[8] = 0xda;
    assert hash[9] = 0xae;
    assert hash[10] = 0x34;
    assert hash[11] = 0x7b;
    assert hash[12] = 0xe6;
    assert hash[13] = 0xf4;
    assert hash[14] = 0xdc;
    assert hash[15] = 0x83;
    assert hash[16] = 0x5a;
    assert hash[17] = 0x46;
    assert hash[18] = 0x7f;
    assert hash[19] = 0xfe;

    return();
}

@external
func test__ripemd160_2{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // message: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopqabcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    // expected hashcode: 69a155bddf855b0973a0791d5b7a3326fb83e163
    alloc_locals;
    let (local msg: felt*) = alloc();
    assert [msg + 0] = 97;
    assert [msg + 1] = 98;
    assert [msg + 2] = 99;
    assert [msg + 3] = 100;
    assert [msg + 4] = 98;
    assert [msg + 5] = 99;
    assert [msg + 6] = 100;
    assert [msg + 7] = 101;
    assert [msg + 8] = 99;
    assert [msg + 9] = 100;
    assert [msg + 10] = 101;
    assert [msg + 11] = 102;
    assert [msg + 12] = 100;
    assert [msg + 13] = 101;
    assert [msg + 14] = 102;
    assert [msg + 15] = 103;
    assert [msg + 16] = 101;
    assert [msg + 17] = 102;
    assert [msg + 18] = 103;
    assert [msg + 19] = 104;
    assert [msg + 20] = 102;
    assert [msg + 21] = 103;
    assert [msg + 22] = 104;
    assert [msg + 23] = 105;
    assert [msg + 24] = 103;
    assert [msg + 25] = 104;
    assert [msg + 26] = 105;
    assert [msg + 27] = 106;
    assert [msg + 28] = 104;
    assert [msg + 29] = 105;
    assert [msg + 30] = 106;
    assert [msg + 31] = 107;
    assert [msg + 32] = 105;
    assert [msg + 33] = 106;
    assert [msg + 34] = 107;
    assert [msg + 35] = 108;
    assert [msg + 36] = 106;
    assert [msg + 37] = 107;
    assert [msg + 38] = 108;
    assert [msg + 39] = 109;
    assert [msg + 40] = 107;
    assert [msg + 41] = 108;
    assert [msg + 42] = 109;
    assert [msg + 43] = 110;
    assert [msg + 44] = 108;
    assert [msg + 45] = 109;
    assert [msg + 46] = 110;
    assert [msg + 47] = 111;
    assert [msg + 48] = 109;
    assert [msg + 49] = 110;
    assert [msg + 50] = 111;
    assert [msg + 51] = 112;
    assert [msg + 52] = 110;
    assert [msg + 53] = 111;
    assert [msg + 54] = 112;
    assert [msg + 55] = 113;
    assert [msg + 56] = 97;
    assert [msg + 57] = 98;
    assert [msg + 58] = 99;
    assert [msg + 59] = 100;
    assert [msg + 60] = 98;
    assert [msg + 61] = 99;
    assert [msg + 62] = 100;
    assert [msg + 63] = 101;
    assert [msg + 64] = 99;
    assert [msg + 65] = 100;
    assert [msg + 66] = 101;
    assert [msg + 67] = 102;
    assert [msg + 68] = 100;
    assert [msg + 69] = 101;
    assert [msg + 70] = 102;
    assert [msg + 71] = 103;
    assert [msg + 72] = 101;
    assert [msg + 73] = 102;
    assert [msg + 74] = 103;
    assert [msg + 75] = 104;
    assert [msg + 76] = 102;
    assert [msg + 77] = 103;
    assert [msg + 78] = 104;
    assert [msg + 79] = 105;
    assert [msg + 80] = 103;
    assert [msg + 81] = 104;
    assert [msg + 82] = 105;
    assert [msg + 83] = 106;
    assert [msg + 84] = 104;
    assert [msg + 85] = 105;
    assert [msg + 86] = 106;
    assert [msg + 87] = 107;
    assert [msg + 88] = 105;
    assert [msg + 89] = 106;
    assert [msg + 90] = 107;
    assert [msg + 91] = 108;
    assert [msg + 92] = 106;
    assert [msg + 93] = 107;
    assert [msg + 94] = 108;
    assert [msg + 95] = 109;
    assert [msg + 96] = 107;
    assert [msg + 97] = 108;
    assert [msg + 98] = 109;
    assert [msg + 99] = 110;
    assert [msg + 100] = 108;
    assert [msg + 101] = 109;
    assert [msg + 102] = 110;
    assert [msg + 103] = 111;
    assert [msg + 104] = 109;
    assert [msg + 105] = 110;
    assert [msg + 106] = 111;
    assert [msg + 107] = 112;
    assert [msg + 108] = 110;
    assert [msg + 109] = 111;
    assert [msg + 110] = 112;
    assert [msg + 111] = 113;

    let (_, hash, _) = PrecompileRIPEMD160.run(112, msg);
    // 69a155bddf855b0973a0791d5b7a3326fb83e163
    assert hash[0] = 0x69;
    assert hash[1] = 0xa1;
    assert hash[2] = 0x55;
    assert hash[3] = 0xbd;
    assert hash[4] = 0xdf;
    assert hash[5] = 0x85;
    assert hash[6] = 0x5b;
    assert hash[7] = 0x09;
    assert hash[8] = 0x73;
    assert hash[9] = 0xa0;
    assert hash[10] = 0x79;
    assert hash[11] = 0x1d;
    assert hash[12] = 0x5b;
    assert hash[13] = 0x7a;
    assert hash[14] = 0x33;
    assert hash[15] = 0x26;
    assert hash[16] = 0xfb;
    assert hash[17] = 0x83;
    assert hash[18] = 0xe1;
    assert hash[19] = 0x63;
    return();
}