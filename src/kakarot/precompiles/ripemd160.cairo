// SPDX-License-Identifier: MIT
// original code from: https://github.com/EulerSmile/ripemd160-cairo

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_nn_le
from starkware.cairo.common.math_cmp import is_nn_le, is_nn
from starkware.cairo.common.bitwise import bitwise_and, bitwise_xor, bitwise_or
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict import dict_read, dict_write
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.memset import memset

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.memory import Memory
from kakarot.evm import EVM

// @title RIPEMD-160 precompile
// @custom:precompile
// @custom:address 0x03
// @notice This precompile serves to hash data with RIPEMD-160
// @author @TurcFort07
// @custom:namespace PrecompileRIPEMD160
namespace PrecompileRIPEMD160 {
    const PRECOMPILE_ADDRESS = 0x03;
    const GAS_COST_RIPEMD160 = 600;

    // @notice Run the precompile.
    // @param input_len The length of input array.
    // @param input The input array.
    // @return output_len The output length.
    // @return output The output array.
    // @return gas_used The gas usage of precompile.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;
        let (local buf: felt*) = alloc();
        let (local arr_x: felt*) = alloc();

        // before starting fill arr_x with  0s to align on 32 bytes (hash length is 20bytes so 12 bytes to fill)
        memset(arr_x, 0, 12);
        let arr_x: felt* = arr_x + 12;

        // 1. init magic constants
        init(buf, 5);

        // 2. compress data
        let (x) = default_dict_new(0);
        let start = x;
        let (res, rsize, new_msg) = compress_data{dict_ptr=x, bitwise_ptr=bitwise_ptr}(
            buf, 5, input_len, input
        );
        default_dict_finalize(start, x, 0);

        // 3. finish hash
        let (res, _) = finish(res, rsize, new_msg, input_len, 0);

        // 4. [optional]convert words to bytes
        let (hash) = default_dict_new(0);
        let h0 = hash;
        buf2hash{dict_ptr=hash, bitwise_ptr=bitwise_ptr}(res, 0);
        dict_to_array{dict_ptr=hash}(arr_x, 20);
        default_dict_finalize(h0, hash, 0);

        // 5. return bytes hash code.
        let (minimum_word_size) = Helpers.minimum_word_count(input_len);
        return (32, arr_x - 12, 120 * minimum_word_size + GAS_COST_RIPEMD160, 0);
    }
}

const MAX_32_BIT = 2 ** 32;
const MAX_BYTE = 2 ** 8;

func buf2hash{range_check_ptr, dict_ptr: DictAccess*, bitwise_ptr: BitwiseBuiltin*}(
    buf: felt*, index: felt
) {
    alloc_locals;
    if (index == 20) {
        return ();
    }

    let (index_4, _) = Helpers.unsigned_div_rem(index, 4);
    let val_4 = buf[index_4];
    let (pow2_8) = pow2(8);
    let (pow2_16) = pow2(16);
    let (pow2_24) = pow2(24);
    let (val_1) = uint8_div(val_4, pow2_8);
    let (val_2) = uint8_div(val_4, pow2_16);
    let (val_3) = uint8_div(val_4, pow2_24);
    let (val_4) = uint8_div(val_4, 1);

    dict_write{dict_ptr=dict_ptr}(index, val_4);
    dict_write{dict_ptr=dict_ptr}(index + 1, val_1);
    dict_write{dict_ptr=dict_ptr}(index + 2, val_2);
    dict_write{dict_ptr=dict_ptr}(index + 3, val_3);

    buf2hash{dict_ptr=dict_ptr, bitwise_ptr=bitwise_ptr}(buf, index + 4);
    return ();
}

func parse_msg{dict_ptr: DictAccess*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    input: felt*, index: felt
) {
    if (index == 16) {
        return ();
    }

    let (val) = BYTES_TO_WORD(input);
    dict_write{dict_ptr=dict_ptr}(index, val);
    parse_msg{dict_ptr=dict_ptr, bitwise_ptr=bitwise_ptr}(input=input + 4, index=index + 1);
    return ();
}

func compress_data{dict_ptr: DictAccess*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    buf: felt*, bufsize: felt, input_len: felt, input: felt*
) -> (res: felt*, rsize: felt, new_msg: felt*) {
    alloc_locals;
    let len_lt_63 = is_nn(63 - input_len);
    if (len_lt_63 == FALSE) {
        parse_msg{dict_ptr=dict_ptr}(input, 0);
        let (local arr_x: felt*) = alloc();
        dict_to_array{dict_ptr=dict_ptr}(arr_x, 16);
        local dict_ptr: DictAccess* = dict_ptr;
        let (res, rsize) = compress(buf, bufsize, arr_x, 16);
        let new_msg = input + 64;
        let (res, rsize, new_msg) = compress_data{dict_ptr=dict_ptr, bitwise_ptr=bitwise_ptr}(
            res, rsize, input_len - 64, new_msg
        );
        return (res=res, rsize=rsize, new_msg=new_msg);
    }
    return (buf, bufsize, input);
}

func absorb_data{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, dict_ptr: DictAccess*}(
    data: felt*, len: felt, index: felt
) {
    alloc_locals;
    if (index - len == 0) {
        return ();
    }

    let (index_4, _) = Helpers.unsigned_div_rem(index, 4);
    let (index_and_3) = uint32_and(index, 3);
    let (factor) = uint32_mul(8, index_and_3);
    let (factor) = pow2(factor);
    let (tmp) = uint32_mul([data], factor);
    let (old_val) = dict_read{dict_ptr=dict_ptr}(index_4);
    let (val) = uint32_xor(old_val, tmp);
    dict_write{dict_ptr=dict_ptr}(index_4, val);

    absorb_data{dict_ptr=dict_ptr}(data + 1, len, index + 1);
    return ();
}

func dict_to_array{dict_ptr: DictAccess*}(arr: felt*, len) {
    if (len == 0) {
        return ();
    }

    let index = len - 1;
    let (x) = dict_read{dict_ptr=dict_ptr}(index);
    assert arr[index] = x;

    dict_to_array{dict_ptr=dict_ptr}(arr, len - 1);

    return ();
}

// init buf to magic constants.
func init(buf: felt*, size: felt) {
    assert size = 5;
    assert [buf + 0] = 0x67452301;
    assert [buf + 1] = 0xefcdab89;
    assert [buf + 2] = 0x98badcfe;
    assert [buf + 3] = 0x10325476;
    assert [buf + 4] = 0xc3d2e1f0;
    return ();
}

// the compression function.
// transforms buf using message bytes X[0] through X[15].
func compress{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
    buf: felt*, bufsize: felt, x: felt*, xlen: felt
) -> (res: felt*, rsize: felt) {
    alloc_locals;

    assert bufsize = 5;
    assert xlen = 16;

    // all element is in [0, 2^32).
    let (_, aa) = Helpers.unsigned_div_rem([buf + 0], MAX_32_BIT);
    let (_, bb) = Helpers.unsigned_div_rem([buf + 1], MAX_32_BIT);
    let (_, cc) = Helpers.unsigned_div_rem([buf + 2], MAX_32_BIT);
    let (_, dd) = Helpers.unsigned_div_rem([buf + 3], MAX_32_BIT);
    let (_, ee) = Helpers.unsigned_div_rem([buf + 4], MAX_32_BIT);
    local aaa = aa;
    local bbb = bb;
    local ccc = cc;
    local ddd = dd;
    local eee = ee;

    // round 1
    let (local aa, local cc) = FF(aa, bb, cc, dd, ee, [x + 0], 11);
    let (local ee, local bb) = FF(ee, aa, bb, cc, dd, [x + 1], 14);
    let (local dd, local aa) = FF(dd, ee, aa, bb, cc, [x + 2], 15);
    let (local cc, local ee) = FF(cc, dd, ee, aa, bb, [x + 3], 12);
    let (local bb, local dd) = FF(bb, cc, dd, ee, aa, [x + 4], 5);
    let (local aa, local cc) = FF(aa, bb, cc, dd, ee, [x + 5], 8);
    let (local ee, local bb) = FF(ee, aa, bb, cc, dd, [x + 6], 7);
    let (local dd, local aa) = FF(dd, ee, aa, bb, cc, [x + 7], 9);
    let (local cc, local ee) = FF(cc, dd, ee, aa, bb, [x + 8], 11);
    let (local bb, local dd) = FF(bb, cc, dd, ee, aa, [x + 9], 13);
    let (local aa, local cc) = FF(aa, bb, cc, dd, ee, [x + 10], 14);
    let (local ee, local bb) = FF(ee, aa, bb, cc, dd, [x + 11], 15);
    let (local dd, local aa) = FF(dd, ee, aa, bb, cc, [x + 12], 6);
    let (local cc, local ee) = FF(cc, dd, ee, aa, bb, [x + 13], 7);
    let (local bb, local dd) = FF(bb, cc, dd, ee, aa, [x + 14], 9);
    let (local aa, local cc) = FF(aa, bb, cc, dd, ee, [x + 15], 8);

    // round 2
    let (local ee, local bb) = GG(ee, aa, bb, cc, dd, [x + 7], 7);
    let (local dd, local aa) = GG(dd, ee, aa, bb, cc, [x + 4], 6);
    let (local cc, local ee) = GG(cc, dd, ee, aa, bb, [x + 13], 8);
    let (local bb, local dd) = GG(bb, cc, dd, ee, aa, [x + 1], 13);
    let (local aa, local cc) = GG(aa, bb, cc, dd, ee, [x + 10], 11);
    let (local ee, local bb) = GG(ee, aa, bb, cc, dd, [x + 6], 9);
    let (local dd, local aa) = GG(dd, ee, aa, bb, cc, [x + 15], 7);
    let (local cc, local ee) = GG(cc, dd, ee, aa, bb, [x + 3], 15);
    let (local bb, local dd) = GG(bb, cc, dd, ee, aa, [x + 12], 7);
    let (local aa, local cc) = GG(aa, bb, cc, dd, ee, [x + 0], 12);
    let (local ee, local bb) = GG(ee, aa, bb, cc, dd, [x + 9], 15);
    let (local dd, local aa) = GG(dd, ee, aa, bb, cc, [x + 5], 9);
    let (local cc, local ee) = GG(cc, dd, ee, aa, bb, [x + 2], 11);
    let (local bb, local dd) = GG(bb, cc, dd, ee, aa, [x + 14], 7);
    let (local aa, local cc) = GG(aa, bb, cc, dd, ee, [x + 11], 13);
    let (local ee, local bb) = GG(ee, aa, bb, cc, dd, [x + 8], 12);

    // round 3
    let (local dd, local aa) = HH(dd, ee, aa, bb, cc, [x + 3], 11);
    let (local cc, local ee) = HH(cc, dd, ee, aa, bb, [x + 10], 13);
    let (local bb, local dd) = HH(bb, cc, dd, ee, aa, [x + 14], 6);
    let (local aa, local cc) = HH(aa, bb, cc, dd, ee, [x + 4], 7);
    let (local ee, local bb) = HH(ee, aa, bb, cc, dd, [x + 9], 14);
    let (local dd, local aa) = HH(dd, ee, aa, bb, cc, [x + 15], 9);
    let (local cc, local ee) = HH(cc, dd, ee, aa, bb, [x + 8], 13);
    let (local bb, local dd) = HH(bb, cc, dd, ee, aa, [x + 1], 15);
    let (local aa, local cc) = HH(aa, bb, cc, dd, ee, [x + 2], 14);
    let (local ee, local bb) = HH(ee, aa, bb, cc, dd, [x + 7], 8);
    let (local dd, local aa) = HH(dd, ee, aa, bb, cc, [x + 0], 13);
    let (local cc, local ee) = HH(cc, dd, ee, aa, bb, [x + 6], 6);
    let (local bb, local dd) = HH(bb, cc, dd, ee, aa, [x + 13], 5);
    let (local aa, local cc) = HH(aa, bb, cc, dd, ee, [x + 11], 12);
    let (local ee, local bb) = HH(ee, aa, bb, cc, dd, [x + 5], 7);
    let (local dd, local aa) = HH(dd, ee, aa, bb, cc, [x + 12], 5);

    // round 4
    let (local cc, local ee) = II(cc, dd, ee, aa, bb, [x + 1], 11);
    let (local bb, local dd) = II(bb, cc, dd, ee, aa, [x + 9], 12);
    let (local aa, local cc) = II(aa, bb, cc, dd, ee, [x + 11], 14);
    let (local ee, local bb) = II(ee, aa, bb, cc, dd, [x + 10], 15);
    let (local dd, local aa) = II(dd, ee, aa, bb, cc, [x + 0], 14);
    let (local cc, local ee) = II(cc, dd, ee, aa, bb, [x + 8], 15);
    let (local bb, local dd) = II(bb, cc, dd, ee, aa, [x + 12], 9);
    let (local aa, local cc) = II(aa, bb, cc, dd, ee, [x + 4], 8);
    let (local ee, local bb) = II(ee, aa, bb, cc, dd, [x + 13], 9);
    let (local dd, local aa) = II(dd, ee, aa, bb, cc, [x + 3], 14);
    let (local cc, local ee) = II(cc, dd, ee, aa, bb, [x + 7], 5);
    let (local bb, local dd) = II(bb, cc, dd, ee, aa, [x + 15], 6);
    let (local aa, local cc) = II(aa, bb, cc, dd, ee, [x + 14], 8);
    let (local ee, local bb) = II(ee, aa, bb, cc, dd, [x + 5], 6);
    let (local dd, local aa) = II(dd, ee, aa, bb, cc, [x + 6], 5);
    let (local cc, local ee) = II(cc, dd, ee, aa, bb, [x + 2], 12);

    // round 5
    let (local bb, local dd) = JJ(bb, cc, dd, ee, aa, [x + 4], 9);
    let (local aa, local cc) = JJ(aa, bb, cc, dd, ee, [x + 0], 15);
    let (local ee, local bb) = JJ(ee, aa, bb, cc, dd, [x + 5], 5);
    let (local dd, local aa) = JJ(dd, ee, aa, bb, cc, [x + 9], 11);
    let (local cc, local ee) = JJ(cc, dd, ee, aa, bb, [x + 7], 6);
    let (local bb, local dd) = JJ(bb, cc, dd, ee, aa, [x + 12], 8);
    let (local aa, local cc) = JJ(aa, bb, cc, dd, ee, [x + 2], 13);
    let (local ee, local bb) = JJ(ee, aa, bb, cc, dd, [x + 10], 12);
    let (local dd, local aa) = JJ(dd, ee, aa, bb, cc, [x + 14], 5);
    let (local cc, local ee) = JJ(cc, dd, ee, aa, bb, [x + 1], 12);
    let (local bb, local dd) = JJ(bb, cc, dd, ee, aa, [x + 3], 13);
    let (local aa, local cc) = JJ(aa, bb, cc, dd, ee, [x + 8], 14);
    let (local ee, local bb) = JJ(ee, aa, bb, cc, dd, [x + 11], 11);
    let (local dd, local aa) = JJ(dd, ee, aa, bb, cc, [x + 6], 8);
    let (local cc, local ee) = JJ(cc, dd, ee, aa, bb, [x + 15], 5);
    let (local bb, local dd) = JJ(bb, cc, dd, ee, aa, [x + 13], 6);

    // parallel round 1
    let (local aaa, local ccc) = JJJ(aaa, bbb, ccc, ddd, eee, [x + 5], 8);
    let (local eee, local bbb) = JJJ(eee, aaa, bbb, ccc, ddd, [x + 14], 9);
    let (local ddd, local aaa) = JJJ(ddd, eee, aaa, bbb, ccc, [x + 7], 9);
    let (local ccc, local eee) = JJJ(ccc, ddd, eee, aaa, bbb, [x + 0], 11);
    let (local bbb, local ddd) = JJJ(bbb, ccc, ddd, eee, aaa, [x + 9], 13);
    let (local aaa, local ccc) = JJJ(aaa, bbb, ccc, ddd, eee, [x + 2], 15);
    let (local eee, local bbb) = JJJ(eee, aaa, bbb, ccc, ddd, [x + 11], 15);
    let (local ddd, local aaa) = JJJ(ddd, eee, aaa, bbb, ccc, [x + 4], 5);
    let (local ccc, local eee) = JJJ(ccc, ddd, eee, aaa, bbb, [x + 13], 7);
    let (local bbb, local ddd) = JJJ(bbb, ccc, ddd, eee, aaa, [x + 6], 7);
    let (local aaa, local ccc) = JJJ(aaa, bbb, ccc, ddd, eee, [x + 15], 8);
    let (local eee, local bbb) = JJJ(eee, aaa, bbb, ccc, ddd, [x + 8], 11);
    let (local ddd, local aaa) = JJJ(ddd, eee, aaa, bbb, ccc, [x + 1], 14);
    let (local ccc, local eee) = JJJ(ccc, ddd, eee, aaa, bbb, [x + 10], 14);
    let (local bbb, local ddd) = JJJ(bbb, ccc, ddd, eee, aaa, [x + 3], 12);
    let (local aaa, local ccc) = JJJ(aaa, bbb, ccc, ddd, eee, [x + 12], 6);

    // parallel round 2
    let (local eee, local bbb) = III(eee, aaa, bbb, ccc, ddd, [x + 6], 9);
    let (local ddd, local aaa) = III(ddd, eee, aaa, bbb, ccc, [x + 11], 13);
    let (local ccc, local eee) = III(ccc, ddd, eee, aaa, bbb, [x + 3], 15);
    let (local bbb, local ddd) = III(bbb, ccc, ddd, eee, aaa, [x + 7], 7);
    let (local aaa, local ccc) = III(aaa, bbb, ccc, ddd, eee, [x + 0], 12);
    let (local eee, local bbb) = III(eee, aaa, bbb, ccc, ddd, [x + 13], 8);
    let (local ddd, local aaa) = III(ddd, eee, aaa, bbb, ccc, [x + 5], 9);
    let (local ccc, local eee) = III(ccc, ddd, eee, aaa, bbb, [x + 10], 11);
    let (local bbb, local ddd) = III(bbb, ccc, ddd, eee, aaa, [x + 14], 7);
    let (local aaa, local ccc) = III(aaa, bbb, ccc, ddd, eee, [x + 15], 7);
    let (local eee, local bbb) = III(eee, aaa, bbb, ccc, ddd, [x + 8], 12);
    let (local ddd, local aaa) = III(ddd, eee, aaa, bbb, ccc, [x + 12], 7);
    let (local ccc, local eee) = III(ccc, ddd, eee, aaa, bbb, [x + 4], 6);
    let (local bbb, local ddd) = III(bbb, ccc, ddd, eee, aaa, [x + 9], 15);
    let (local aaa, local ccc) = III(aaa, bbb, ccc, ddd, eee, [x + 1], 13);
    let (local eee, local bbb) = III(eee, aaa, bbb, ccc, ddd, [x + 2], 11);

    // parallel round 3
    let (local ddd, local aaa) = HHH(ddd, eee, aaa, bbb, ccc, [x + 15], 9);
    let (local ccc, local eee) = HHH(ccc, ddd, eee, aaa, bbb, [x + 5], 7);
    let (local bbb, local ddd) = HHH(bbb, ccc, ddd, eee, aaa, [x + 1], 15);
    let (local aaa, local ccc) = HHH(aaa, bbb, ccc, ddd, eee, [x + 3], 11);
    let (local eee, local bbb) = HHH(eee, aaa, bbb, ccc, ddd, [x + 7], 8);
    let (local ddd, local aaa) = HHH(ddd, eee, aaa, bbb, ccc, [x + 14], 6);
    let (local ccc, local eee) = HHH(ccc, ddd, eee, aaa, bbb, [x + 6], 6);
    let (local bbb, local ddd) = HHH(bbb, ccc, ddd, eee, aaa, [x + 9], 14);
    let (local aaa, local ccc) = HHH(aaa, bbb, ccc, ddd, eee, [x + 11], 12);
    let (local eee, local bbb) = HHH(eee, aaa, bbb, ccc, ddd, [x + 8], 13);
    let (local ddd, local aaa) = HHH(ddd, eee, aaa, bbb, ccc, [x + 12], 5);
    let (local ccc, local eee) = HHH(ccc, ddd, eee, aaa, bbb, [x + 2], 14);
    let (local bbb, local ddd) = HHH(bbb, ccc, ddd, eee, aaa, [x + 10], 13);
    let (local aaa, local ccc) = HHH(aaa, bbb, ccc, ddd, eee, [x + 0], 13);
    let (local eee, local bbb) = HHH(eee, aaa, bbb, ccc, ddd, [x + 4], 7);
    let (local ddd, local aaa) = HHH(ddd, eee, aaa, bbb, ccc, [x + 13], 5);

    // parallel round 4
    let (local ccc, local eee) = GGG(ccc, ddd, eee, aaa, bbb, [x + 8], 15);
    let (local bbb, local ddd) = GGG(bbb, ccc, ddd, eee, aaa, [x + 6], 5);
    let (local aaa, local ccc) = GGG(aaa, bbb, ccc, ddd, eee, [x + 4], 8);
    let (local eee, local bbb) = GGG(eee, aaa, bbb, ccc, ddd, [x + 1], 11);
    let (local ddd, local aaa) = GGG(ddd, eee, aaa, bbb, ccc, [x + 3], 14);
    let (local ccc, local eee) = GGG(ccc, ddd, eee, aaa, bbb, [x + 11], 14);
    let (local bbb, local ddd) = GGG(bbb, ccc, ddd, eee, aaa, [x + 15], 6);
    let (local aaa, local ccc) = GGG(aaa, bbb, ccc, ddd, eee, [x + 0], 14);
    let (local eee, local bbb) = GGG(eee, aaa, bbb, ccc, ddd, [x + 5], 6);
    let (local ddd, local aaa) = GGG(ddd, eee, aaa, bbb, ccc, [x + 12], 9);
    let (local ccc, local eee) = GGG(ccc, ddd, eee, aaa, bbb, [x + 2], 12);
    let (local bbb, local ddd) = GGG(bbb, ccc, ddd, eee, aaa, [x + 13], 9);
    let (local aaa, local ccc) = GGG(aaa, bbb, ccc, ddd, eee, [x + 9], 12);
    let (local eee, local bbb) = GGG(eee, aaa, bbb, ccc, ddd, [x + 7], 5);
    let (local ddd, local aaa) = GGG(ddd, eee, aaa, bbb, ccc, [x + 10], 15);
    let (local ccc, local eee) = GGG(ccc, ddd, eee, aaa, bbb, [x + 14], 8);

    // parallel round 5
    let (local bbb, local ddd) = FFF(bbb, ccc, ddd, eee, aaa, [x + 12], 8);
    let (local aaa, local ccc) = FFF(aaa, bbb, ccc, ddd, eee, [x + 15], 5);
    let (local eee, local bbb) = FFF(eee, aaa, bbb, ccc, ddd, [x + 10], 12);
    let (local ddd, local aaa) = FFF(ddd, eee, aaa, bbb, ccc, [x + 4], 9);
    let (local ccc, local eee) = FFF(ccc, ddd, eee, aaa, bbb, [x + 1], 12);
    let (local bbb, local ddd) = FFF(bbb, ccc, ddd, eee, aaa, [x + 5], 5);
    let (local aaa, local ccc) = FFF(aaa, bbb, ccc, ddd, eee, [x + 8], 14);
    let (local eee, local bbb) = FFF(eee, aaa, bbb, ccc, ddd, [x + 7], 6);
    let (local ddd, local aaa) = FFF(ddd, eee, aaa, bbb, ccc, [x + 6], 8);
    let (local ccc, local eee) = FFF(ccc, ddd, eee, aaa, bbb, [x + 2], 13);
    let (local bbb, local ddd) = FFF(bbb, ccc, ddd, eee, aaa, [x + 13], 6);
    let (local aaa, local ccc) = FFF(aaa, bbb, ccc, ddd, eee, [x + 14], 5);
    let (local eee, local bbb) = FFF(eee, aaa, bbb, ccc, ddd, [x + 0], 15);
    let (local ddd, local aaa) = FFF(ddd, eee, aaa, bbb, ccc, [x + 3], 13);
    let (local ccc, local eee) = FFF(ccc, ddd, eee, aaa, bbb, [x + 9], 11);
    let (local bbb, local ddd) = FFF(bbb, ccc, ddd, eee, aaa, [x + 11], 11);

    // combine results
    let (local res: felt*) = alloc();

    let (res0) = uint32_add([buf + 1], cc);
    let (res0) = uint32_add(res0, ddd);

    let (res1) = uint32_add([buf + 2], dd);
    let (res1) = uint32_add(res1, eee);

    let (res2) = uint32_add([buf + 3], ee);
    let (res2) = uint32_add(res2, aaa);

    let (res3) = uint32_add([buf + 4], aa);
    let (res3) = uint32_add(res3, bbb);

    let (res4) = uint32_add([buf + 0], bb);
    let (res4) = uint32_add(res4, ccc);

    assert res[0] = res0;
    assert res[1] = res1;
    assert res[2] = res2;
    assert res[3] = res3;
    assert res[4] = res4;

    return (res=res, rsize=5);
}

// puts bytes from data into X and pad out; appends length
// and finally, compresses the last block(s)
// note: length in bits == 8 * (dsize + 2^32 mswlen).
// note: there are (dsize mod 64) bytes left in data.
func finish{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    buf: felt*, bufsize: felt, data: felt*, dsize: felt, mswlen: felt
) -> (res: felt*, rsize: felt) {
    alloc_locals;
    let (x) = default_dict_new(0);
    tempvar start = x;

    // put data into x.
    let (local len) = uint32_and(dsize, 63);
    absorb_data{dict_ptr=x}(data, len, 0);

    // append the bit m_n == 1.
    let (index_4, _) = Helpers.unsigned_div_rem(dsize, 4);
    let (local index) = uint32_and(index_4, 15);
    let (old_val) = dict_read{dict_ptr=x}(index);
    let (local ba_3) = uint32_and(dsize, 3);
    let (factor) = uint32_add(8 * ba_3, 7);
    let (tmp) = pow2(factor);
    let (local val) = uint32_xor(old_val, tmp);
    dict_write{dict_ptr=x}(index, val);

    // length goes to next block.
    let (val) = uint32_mul(dsize, 8);
    let (pow2_29) = pow2(29);
    let (factor, _) = Helpers.unsigned_div_rem(dsize, pow2_29);
    let len_8 = mswlen * 8;
    let (val_15) = uint32_or(factor, len_8);

    let next_block = is_nn_le(55, len);
    if (next_block == FALSE) {
        dict_write{dict_ptr=x}(14, val);
        dict_write{dict_ptr=x}(15, val_15);

        let (local arr_x: felt*) = alloc();
        dict_to_array{dict_ptr=x}(arr_x, 16);
        default_dict_finalize(start, x, 0);
        let (res, rsize) = compress(buf, bufsize, arr_x, 16);
        return (res=res, rsize=rsize);
    }
    let (local arr_x: felt*) = alloc();
    dict_to_array{dict_ptr=x}(arr_x, 16);
    let (buf, bufsize) = compress(buf, bufsize, arr_x, 16);
    // reset dict to all 0.
    let (x) = default_dict_new(0);

    dict_write{dict_ptr=x}(14, val);
    dict_write{dict_ptr=x}(15, val_15);

    let (local arr_x: felt*) = alloc();
    dict_to_array{dict_ptr=x}(arr_x, 16);
    default_dict_finalize(start, x, 0);
    let (res, rsize) = compress(buf, bufsize, arr_x, 16);
    return (res=res, rsize=rsize);
}

func uint8_div{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y) -> (z: felt) {
    let (z, _) = Helpers.unsigned_div_rem(x, y);
    let (_, z) = Helpers.unsigned_div_rem(z, MAX_BYTE);
    return (z=z);
}

func uint32_add{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y) -> (z: felt) {
    let (_, z) = Helpers.unsigned_div_rem(x + y, MAX_32_BIT);
    return (z=z);
}

func uint32_mul{range_check_ptr}(x, y) -> (z: felt) {
    let (_, z) = Helpers.unsigned_div_rem(x * y, MAX_32_BIT);
    return (z=z);
}

func uint32_and{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y) -> (z: felt) {
    let (z) = bitwise_and(x, y);
    let (_, z) = Helpers.unsigned_div_rem(z, MAX_32_BIT);
    return (z=z);
}

func uint32_or{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y) -> (z: felt) {
    let (z) = bitwise_or(x, y);
    let (_, z) = Helpers.unsigned_div_rem(z, MAX_32_BIT);
    return (z=z);
}

func uint32_not{range_check_ptr}(x: felt) -> (not_x: felt) {
    let not_x = MAX_32_BIT - 1 - x;
    let (_, not_x) = Helpers.unsigned_div_rem(not_x, MAX_32_BIT);
    return (not_x=not_x);
}

func uint32_xor{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y) -> (z: felt) {
    let (z) = bitwise_xor(x, y);
    let (_, z) = Helpers.unsigned_div_rem(z, MAX_32_BIT);
    return (z=z);
}

// collect four bytes into one word.
func BYTES_TO_WORD{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x: felt*) -> (res: felt) {
    alloc_locals;
    let (factor_3) = pow2(24);
    let (factor_2) = pow2(16);
    let (factor_1) = pow2(8);
    let (l1) = uint32_mul([x + 3], factor_3);
    let (l2) = uint32_mul([x + 2], factor_2);
    let (l3) = uint32_mul([x + 1], factor_1);
    let (l1_or_l2) = uint32_or(l1, l2);
    let (l1_or_l2_or_l3) = uint32_or(l1_or_l2, l3);
    let (res) = uint32_or(l1_or_l2_or_l3, [x]);
    return (res=res);
}

// ROL(x, n) cyclically rotates x over n bits to the left
// x must be mod of an unsigned 32 bits type and 0 <= n < 32.
func ROL{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, n) -> (res: felt) {
    alloc_locals;
    assert_nn_le(x, 2 ** 32 - 1);
    assert_nn_le(n, 31);

    let (factor_n) = pow2(n);
    let (factor_diff) = pow2(32 - n);
    let (x_left_shift) = uint32_mul(x, factor_n);
    let (x_right_shift, _) = Helpers.unsigned_div_rem(x, factor_diff);
    let (res) = uint32_or(x_left_shift, x_right_shift);
    return (res=res);
}

// the five basic functions F(), G(), H(), I(), J().
func F{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y, z) -> (res: felt) {
    let (x_xor_y) = uint32_xor(x, y);
    let (res) = uint32_xor(x_xor_y, z);
    return (res=res);
}

func G{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y, z) -> (res: felt) {
    let (x_and_y) = uint32_and(x, y);
    let (not_x) = uint32_not(x);
    let (not_x_and_z) = uint32_and(not_x, z);
    let (res) = uint32_or(x_and_y, not_x_and_z);
    return (res=res);
}

func H{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y, z) -> (res: felt) {
    let (not_y) = uint32_not(y);
    let (x_or_not_y) = uint32_or(x, not_y);
    let (res) = uint32_xor(x_or_not_y, z);
    return (res=res);
}

func I{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y, z) -> (res: felt) {
    let (x_and_z) = uint32_and(x, z);
    let (not_z) = uint32_not(z);
    let (y_and_not_z) = uint32_and(y, not_z);
    let (res) = uint32_or(x_and_z, y_and_not_z);
    return (res=res);
}

func J{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(x, y, z) -> (res: felt) {
    let (not_z) = uint32_not(z);
    let (y_or_not_z) = uint32_or(y, not_z);
    let (res) = uint32_xor(x, y_or_not_z);
    return (res=res);
}

// the ten basic operations FF() through JJJ().
func ROLASE{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, s, e) -> (res: felt) {
    let (rol_a_s) = ROL(a, s);
    let (res) = uint32_add(rol_a_s, e);
    return (res=res);
}

func FF{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;

    let (f_bcd) = F(b, c, d);
    let (a) = uint32_add(a, f_bcd);
    let (a) = uint32_add(a, x);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func GG{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (g_bcd) = G(b, c, d);
    let (a) = uint32_add(a, g_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x5a827999);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func HH{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (h_bcd) = H(b, c, d);
    let (a) = uint32_add(a, h_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x6ed9eba1);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func II{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (i_bcd) = I(b, c, d);
    let (a) = uint32_add(a, i_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x8f1bbcdc);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func JJ{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (j_bcd) = J(b, c, d);
    let (a) = uint32_add(a, j_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0xa953fd4e);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func FFF{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    let (res1: felt, res2: felt) = FF(a, b, c, d, e, x, s);
    return (res1=res1, res2=res2);
}

func GGG{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (g_bcd) = G(b, c, d);
    let (a) = uint32_add(a, g_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x7a6d76e9);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func HHH{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (h_bcd) = H(b, c, d);
    let (a) = uint32_add(a, h_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x6d703ef3);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func III{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (i_bcd) = I(b, c, d);
    let (a) = uint32_add(a, i_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x5c4dd124);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

func JJJ{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(a, b, c, d, e, x, s) -> (
    res1: felt, res2: felt
) {
    alloc_locals;
    let (j_bcd) = J(b, c, d);
    let (a) = uint32_add(a, j_bcd);
    let (a) = uint32_add(a, x);
    let (a) = uint32_add(a, 0x50a28be6);
    let (res1) = ROLASE(a, s, e);
    let (res2) = ROL(c, 10);
    return (res1=res1, res2=res2);
}

// This is taken from https://github.com/greenlucid/chess-cairo.
func pow2(i: felt) -> (res: felt) {
    let (data_address) = get_label_location(data);
    return (res=[data_address + i]);

    data:
    dw 1;
    dw 2;
    dw 4;
    dw 8;
    dw 16;
    dw 32;
    dw 64;
    dw 128;
    dw 256;
    dw 512;
    dw 1024;
    dw 2048;
    dw 4096;
    dw 8192;
    dw 16384;
    dw 32768;
    dw 65536;
    dw 131072;
    dw 262144;
    dw 524288;
    dw 1048576;
    dw 2097152;
    dw 4194304;
    dw 8388608;
    dw 16777216;
    dw 33554432;
    dw 67108864;
    dw 134217728;
    dw 268435456;
    dw 536870912;
    dw 1073741824;
    dw 2147483648;
    dw 4294967296;
    dw 8589934592;
    dw 17179869184;
    dw 34359738368;
    dw 68719476736;
    dw 137438953472;
    dw 274877906944;
    dw 549755813888;
    dw 1099511627776;
    dw 2199023255552;
    dw 4398046511104;
    dw 8796093022208;
    dw 17592186044416;
    dw 35184372088832;
    dw 70368744177664;
    dw 140737488355328;
    dw 281474976710656;
    dw 562949953421312;
    dw 1125899906842624;
    dw 2251799813685248;
    dw 4503599627370496;
    dw 9007199254740992;
    dw 18014398509481984;
    dw 36028797018963968;
    dw 72057594037927936;
    dw 144115188075855872;
    dw 288230376151711744;
    dw 576460752303423488;
    dw 1152921504606846976;
    dw 2305843009213693952;
    dw 4611686018427387904;
    dw 9223372036854775808;
    dw 18446744073709551616;
    dw 36893488147419103232;
    dw 73786976294838206464;
    dw 147573952589676412928;
    dw 295147905179352825856;
    dw 590295810358705651712;
    dw 1180591620717411303424;
    dw 2361183241434822606848;
    dw 4722366482869645213696;
    dw 9444732965739290427392;
    dw 18889465931478580854784;
    dw 37778931862957161709568;
    dw 75557863725914323419136;
    dw 151115727451828646838272;
    dw 302231454903657293676544;
    dw 604462909807314587353088;
    dw 1208925819614629174706176;
    dw 2417851639229258349412352;
    dw 4835703278458516698824704;
    dw 9671406556917033397649408;
    dw 19342813113834066795298816;
    dw 38685626227668133590597632;
    dw 77371252455336267181195264;
    dw 154742504910672534362390528;
    dw 309485009821345068724781056;
    dw 618970019642690137449562112;
    dw 1237940039285380274899124224;
    dw 2475880078570760549798248448;
    dw 4951760157141521099596496896;
    dw 9903520314283042199192993792;
    dw 19807040628566084398385987584;
    dw 39614081257132168796771975168;
    dw 79228162514264337593543950336;
    dw 158456325028528675187087900672;
    dw 316912650057057350374175801344;
    dw 633825300114114700748351602688;
    dw 1267650600228229401496703205376;
    dw 2535301200456458802993406410752;
    dw 5070602400912917605986812821504;
    dw 10141204801825835211973625643008;
    dw 20282409603651670423947251286016;
    dw 40564819207303340847894502572032;
    dw 81129638414606681695789005144064;
    dw 162259276829213363391578010288128;
    dw 324518553658426726783156020576256;
    dw 649037107316853453566312041152512;
    dw 1298074214633706907132624082305024;
    dw 2596148429267413814265248164610048;
    dw 5192296858534827628530496329220096;
    dw 10384593717069655257060992658440192;
    dw 20769187434139310514121985316880384;
    dw 41538374868278621028243970633760768;
    dw 83076749736557242056487941267521536;
    dw 166153499473114484112975882535043072;
    dw 332306998946228968225951765070086144;
    dw 664613997892457936451903530140172288;
    dw 1329227995784915872903807060280344576;
    dw 2658455991569831745807614120560689152;
    dw 5316911983139663491615228241121378304;
    dw 10633823966279326983230456482242756608;
    dw 21267647932558653966460912964485513216;
    dw 42535295865117307932921825928971026432;
    dw 85070591730234615865843651857942052864;
    dw 170141183460469231731687303715884105728;
    dw 340282366920938463463374607431768211456;
    dw 680564733841876926926749214863536422912;
    dw 1361129467683753853853498429727072845824;
    dw 2722258935367507707706996859454145691648;
    dw 5444517870735015415413993718908291383296;
    dw 10889035741470030830827987437816582766592;
    dw 21778071482940061661655974875633165533184;
    dw 43556142965880123323311949751266331066368;
    dw 87112285931760246646623899502532662132736;
    dw 174224571863520493293247799005065324265472;
    dw 348449143727040986586495598010130648530944;
    dw 696898287454081973172991196020261297061888;
    dw 1393796574908163946345982392040522594123776;
    dw 2787593149816327892691964784081045188247552;
    dw 5575186299632655785383929568162090376495104;
    dw 11150372599265311570767859136324180752990208;
    dw 22300745198530623141535718272648361505980416;
    dw 44601490397061246283071436545296723011960832;
    dw 89202980794122492566142873090593446023921664;
    dw 178405961588244985132285746181186892047843328;
    dw 356811923176489970264571492362373784095686656;
    dw 713623846352979940529142984724747568191373312;
    dw 1427247692705959881058285969449495136382746624;
    dw 2854495385411919762116571938898990272765493248;
    dw 5708990770823839524233143877797980545530986496;
    dw 11417981541647679048466287755595961091061972992;
    dw 22835963083295358096932575511191922182123945984;
    dw 45671926166590716193865151022383844364247891968;
    dw 91343852333181432387730302044767688728495783936;
    dw 182687704666362864775460604089535377456991567872;
    dw 365375409332725729550921208179070754913983135744;
    dw 730750818665451459101842416358141509827966271488;
    dw 1461501637330902918203684832716283019655932542976;
    dw 2923003274661805836407369665432566039311865085952;
    dw 5846006549323611672814739330865132078623730171904;
    dw 11692013098647223345629478661730264157247460343808;
    dw 23384026197294446691258957323460528314494920687616;
    dw 46768052394588893382517914646921056628989841375232;
    dw 93536104789177786765035829293842113257979682750464;
    dw 187072209578355573530071658587684226515959365500928;
    dw 374144419156711147060143317175368453031918731001856;
    dw 748288838313422294120286634350736906063837462003712;
    dw 1496577676626844588240573268701473812127674924007424;
    dw 2993155353253689176481146537402947624255349848014848;
    dw 5986310706507378352962293074805895248510699696029696;
    dw 11972621413014756705924586149611790497021399392059392;
    dw 23945242826029513411849172299223580994042798784118784;
    dw 47890485652059026823698344598447161988085597568237568;
    dw 95780971304118053647396689196894323976171195136475136;
    dw 191561942608236107294793378393788647952342390272950272;
    dw 383123885216472214589586756787577295904684780545900544;
    dw 766247770432944429179173513575154591809369561091801088;
    dw 1532495540865888858358347027150309183618739122183602176;
    dw 3064991081731777716716694054300618367237478244367204352;
    dw 6129982163463555433433388108601236734474956488734408704;
    dw 12259964326927110866866776217202473468949912977468817408;
    dw 24519928653854221733733552434404946937899825954937634816;
    dw 49039857307708443467467104868809893875799651909875269632;
    dw 98079714615416886934934209737619787751599303819750539264;
    dw 196159429230833773869868419475239575503198607639501078528;
    dw 392318858461667547739736838950479151006397215279002157056;
    dw 784637716923335095479473677900958302012794430558004314112;
    dw 1569275433846670190958947355801916604025588861116008628224;
    dw 3138550867693340381917894711603833208051177722232017256448;
    dw 6277101735386680763835789423207666416102355444464034512896;
    dw 12554203470773361527671578846415332832204710888928069025792;
    dw 25108406941546723055343157692830665664409421777856138051584;
    dw 50216813883093446110686315385661331328818843555712276103168;
    dw 100433627766186892221372630771322662657637687111424552206336;
    dw 200867255532373784442745261542645325315275374222849104412672;
    dw 401734511064747568885490523085290650630550748445698208825344;
    dw 803469022129495137770981046170581301261101496891396417650688;
    dw 1606938044258990275541962092341162602522202993782792835301376;
    dw 3213876088517980551083924184682325205044405987565585670602752;
    dw 6427752177035961102167848369364650410088811975131171341205504;
    dw 12855504354071922204335696738729300820177623950262342682411008;
    dw 25711008708143844408671393477458601640355247900524685364822016;
    dw 51422017416287688817342786954917203280710495801049370729644032;
    dw 102844034832575377634685573909834406561420991602098741459288064;
    dw 205688069665150755269371147819668813122841983204197482918576128;
    dw 411376139330301510538742295639337626245683966408394965837152256;
    dw 822752278660603021077484591278675252491367932816789931674304512;
    dw 1645504557321206042154969182557350504982735865633579863348609024;
    dw 3291009114642412084309938365114701009965471731267159726697218048;
    dw 6582018229284824168619876730229402019930943462534319453394436096;
    dw 13164036458569648337239753460458804039861886925068638906788872192;
    dw 26328072917139296674479506920917608079723773850137277813577744384;
    dw 52656145834278593348959013841835216159447547700274555627155488768;
    dw 105312291668557186697918027683670432318895095400549111254310977536;
    dw 210624583337114373395836055367340864637790190801098222508621955072;
    dw 421249166674228746791672110734681729275580381602196445017243910144;
    dw 842498333348457493583344221469363458551160763204392890034487820288;
    dw 1684996666696914987166688442938726917102321526408785780068975640576;
    dw 3369993333393829974333376885877453834204643052817571560137951281152;
    dw 6739986666787659948666753771754907668409286105635143120275902562304;
    dw 13479973333575319897333507543509815336818572211270286240551805124608;
    dw 26959946667150639794667015087019630673637144422540572481103610249216;
    dw 53919893334301279589334030174039261347274288845081144962207220498432;
    dw 107839786668602559178668060348078522694548577690162289924414440996864;
    dw 215679573337205118357336120696157045389097155380324579848828881993728;
    dw 431359146674410236714672241392314090778194310760649159697657763987456;
    dw 862718293348820473429344482784628181556388621521298319395315527974912;
    dw 1725436586697640946858688965569256363112777243042596638790631055949824;
    dw 3450873173395281893717377931138512726225554486085193277581262111899648;
    dw 6901746346790563787434755862277025452451108972170386555162524223799296;
    dw 13803492693581127574869511724554050904902217944340773110325048447598592;
    dw 27606985387162255149739023449108101809804435888681546220650096895197184;
    dw 55213970774324510299478046898216203619608871777363092441300193790394368;
    dw 110427941548649020598956093796432407239217743554726184882600387580788736;
    dw 220855883097298041197912187592864814478435487109452369765200775161577472;
    dw 441711766194596082395824375185729628956870974218904739530401550323154944;
    dw 883423532389192164791648750371459257913741948437809479060803100646309888;
    dw 1766847064778384329583297500742918515827483896875618958121606201292619776;
    dw 3533694129556768659166595001485837031654967793751237916243212402585239552;
    dw 7067388259113537318333190002971674063309935587502475832486424805170479104;
    dw 14134776518227074636666380005943348126619871175004951664972849610340958208;
    dw 28269553036454149273332760011886696253239742350009903329945699220681916416;
    dw 56539106072908298546665520023773392506479484700019806659891398441363832832;
    dw 113078212145816597093331040047546785012958969400039613319782796882727665664;
    dw 226156424291633194186662080095093570025917938800079226639565593765455331328;
    dw 452312848583266388373324160190187140051835877600158453279131187530910662656;
    dw 904625697166532776746648320380374280103671755200316906558262375061821325312;
    dw 1809251394333065553493296640760748560207343510400633813116524750123642650624;
}
