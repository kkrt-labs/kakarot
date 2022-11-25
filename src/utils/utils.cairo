// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le, split_felt, assert_nn_le, split_int
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.registers import get_label_location

// @title Helper Functions
// @notice This file contains a selection of helper function that simplify tasks such as type conversion and bit manipulation
// @author @abdelhamidbakhta
// @custom:namespace Helpers
namespace Helpers {
    func to_uint256{range_check_ptr}(val: felt) -> Uint256 {
        let (high, low) = split_felt(val);
        let res = Uint256(low, high);
        return res;
    }

    // @notice This function is used to convert a sequence of 32 bytes to Uint256.
    // @param val: pointer to the first byte of the 32.
    // @return res: Uint256 representation of the given input in bytes32.
    func bytes32_to_uint256(val: felt*) -> Uint256 {
        let res = Uint256(
            low=[val + 16] * 256 ** 15 + [val + 17] * 256 ** 14 + [val + 18] * 256 ** 13 + [val + 19] * 256 ** 12 + [val + 20] * 256 ** 11 + [val + 21] * 256 ** 10 + [val + 22] * 256 ** 9 + [val + 23] * 256 ** 8 + [val + 24] * 256 ** 7 + [val + 25] * 256 ** 6 + [val + 26] * 256 ** 5 + [val + 27] * 256 ** 4 + [val + 28] * 256 ** 3 + [val + 29] * 256 ** 2 + [val + 30] * 256 + [val + 31],
            high=[val] * 256 ** 15 + [val + 1] * 256 ** 14 + [val + 2] * 256 ** 13 + [val + 3] * 256 ** 12 + [val + 4] * 256 ** 11 + [val + 5] * 256 ** 10 + [val + 6] * 256 ** 9 + [val + 7] * 256 ** 8 + [val + 8] * 256 ** 7 + [val + 9] * 256 ** 6 + [val + 10] * 256 ** 5 + [val + 11] * 256 ** 4 + [val + 12] * 256 ** 3 + [val + 13] * 256 ** 2 + [val + 14] * 256 + [val + 15],
        );
        return res;
    }
    // @notice This function is used to convert a sequence of i bytes to Uint256.
    // @param val: pointer to the first byte.
    // @param i: pointer to the first byte.
    // @return res: Uint256 representation of the given input in bytes.
    func bytes_i_to_uint256{range_check_ptr}(val: felt*, i: felt) -> Uint256 {
        alloc_locals;
        local new_i: felt;
        local new_val: felt*;
        local high: felt;

        // Check if i is lower to 32
        let is_le32 = is_le(i, 32);
        with_attr error_message("number must be shorter than 32 bytes") {
            assert is_le32 = 1;
        }

        let is_16_le_i = is_le(16, i);
        if (is_16_le_i == 1) {
            assert new_val = val + i - 16;
            new_i = 16;
            let (high_temp) = compute_half_uint256(val=val, i=i - 16, res=0);
            high = high_temp;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            new_val = val;
            new_i = i;
            high = 0;
            tempvar range_check_ptr = range_check_ptr;
        }

        let is_i_le_16 = is_le(new_i, 16);

        if (is_i_le_16 == 1) {
            let (low) = compute_half_uint256(val=new_val, i=new_i, res=0);
            let res = Uint256(low=low, high=high);
            return res;
        } else {
            let low = 0;
            let res = Uint256(low=low, high=high);
            return res;
        }
    }

    func compute_half_uint256{range_check_ptr}(val: felt*, i: felt, res: felt) -> (res: felt) {
        if (i == 1) {
            return (res=res + [val]);
        } else {
            let (temp_pow) = pow(256, i - 1);
            let (res) = compute_half_uint256(val + 1, i - 1, res + [val] * temp_pow);
            return (res=res);
        }
    }

    // @notice This function is used to convert a sequence of 8 bytes to a felt.
    // @param val: pointer to the first byte.
    // @return: felt representation of the input.
    func bytes_to_64_bits_little_felt(bytes: felt*) -> felt {
        return [bytes + 7] * 256 ** 7 + [bytes + 6] * 256 ** 6 + [bytes + 5] * 256 ** 5 + [bytes + 4] * 256 ** 4 + [bytes + 3] * 256 ** 3 + [bytes + 2] * 256 ** 2 + [bytes + 1] * 256 + [bytes];
    }

    // @notice This function is used to make an arbitrary length array of same elements.
    // @param arr: pointer to the first element
    // @param value: value to place
    // @param arr_len: number of elements to add.
    func fill(arr_len: felt, arr: felt*, value: felt) {
        if (arr_len == 0) {
            return ();
        }
        assert [arr] = value;
        return fill(arr_len - 1, arr + 1, value);
    }

    // @notice This function fills an empty array with elements from another array
    // @param fill_len: number of elements to add
    // @param input_arr: pointer to the input array
    // @param output_arr: pointer to empty array to be filled with elements from input array
    func fill_array(fill_len: felt, input_arr: felt*, output_arr: felt*) {
        if (fill_len == 0) {
            return ();
        }
        assert [output_arr] = [input_arr];
        return fill_array(fill_len - 1, input_arr + 1, output_arr + 1);
    }

    func slice_data{range_check_ptr}(
        data_len: felt, data: felt*, data_offset: felt, slice_len: felt
    ) -> felt* {
        alloc_locals;
        local len: felt;
        let (local new_data: felt*) = alloc();

        // slice's len = min(slice_len, data_len-offset, 0)
        // which corresponds to full, partial or empty overlap with data
        // The result is zero-padded in case of partial or empty overlap.

        let is_non_empty: felt = is_le(data_offset, data_len);
        let max_len: felt = (data_len - data_offset) * is_non_empty;
        let is_within_bound: felt = is_le(slice_len, max_len);
        let len = max_len + (slice_len - max_len) * is_within_bound;

        memcpy(dst=new_data, src=data + data_offset, len=len);
        fill(arr_len=slice_len - len, arr=new_data + len, value=0);
        return new_data;
    }

    func reverse(old_arr_len: felt, old_arr: felt*, new_arr_len: felt, new_arr: felt*) {
        if (old_arr_len == 0) {
            return ();
        }
        assert new_arr[old_arr_len - 1] = [old_arr];
        return reverse(old_arr_len - 1, &old_arr[1], new_arr_len + 1, new_arr);
    }

    // @notice This function is used to convert a uint256 to a felt.
    // @param val: value to convert.
    // @return: felt representation of the input.
    func uint256_to_felt{range_check_ptr}(val: Uint256) -> felt {
        return val.low + val.high * 2 ** 128;
    }

    // @notice This function is used to convert a uint256 to a bytes array represented by an array of felts (1 felt represents 1 byte).
    // @param value: value to convert.
    // @return: array length and felt array representation of the value.
    func uint256_to_bytes_array{range_check_ptr}(value: Uint256) -> (
        bytes_array_len: felt, bytes_array: felt*
    ) {
        alloc_locals;
        // Split the stack popped value from Uint to bytes array
        let (local temp_value: felt*) = alloc();
        let (local value_as_bytes_array: felt*) = alloc();
        split_int(value=value.high, n=16, base=2 ** 8, bound=2 ** 128, output=temp_value + 16);
        split_int(value=value.low, n=16, base=2 ** 8, bound=2 ** 128, output=temp_value);
        // Reverse the temp_value array into value_as_bytes_array as memory is arranged in big endian order.
        reverse(old_arr_len=32, old_arr=temp_value, new_arr_len=32, new_arr=value_as_bytes_array);
        return (bytes_array_len=32, bytes_array=value_as_bytes_array);
    }

    // @notice Loads a sequence of bytes into a single felt in big-endian.
    // @param len: number of bytes.
    // @param ptr: pointer to bytes array.
    // @return: packed felt.
    func load_word(len: felt, ptr: felt*) -> felt {
        if (len == 0) {
            return 0;
        }
        tempvar current = 0;

        // len, ptr, ?, ?, current
        loop:
        let len = [ap - 5];
        let ptr = cast([ap - 4], felt*);
        let current = [ap - 1];

        tempvar len = len - 1;
        tempvar ptr = ptr + 1;
        tempvar loaded = [ptr - 1];
        tempvar tmp = current * 256;
        tempvar current = tmp + loaded;

        static_assert len == [ap - 5];
        static_assert ptr == [ap - 4];
        static_assert current == [ap - 1];
        jmp loop if len != 0;

        return current;
    }

    // @notice Divides a 128-bit number with remainder.
    // @dev This is almost identical to cairo.common.math.unsigned_dev_rem, but supports the case
    // @dev of div == 2**128 as well.
    // @param value: 128bit value to divide.
    // @param div: divisor.
    // @return: quotient and remainder.
    func div_rem{range_check_ptr}(value, div) -> (q: felt, r: felt) {
        if (div == 2 ** 128) {
            return (0, value);
        }

        // Copied from unsigned_div_rem.
        let r = [range_check_ptr];
        let q = [range_check_ptr + 1];
        let range_check_ptr = range_check_ptr + 2;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.div)
            assert 0 < ids.div <= PRIME // range_check_builtin.bound, \
                f'div={hex(ids.div)} is out of the valid range.'
            ids.q, ids.r = divmod(ids.value, ids.div)
        %}
        assert_le(r, div - 1);

        assert value = q * div + r;
        return (q, r);
    }

    // @notice Computes 256 ** (16 - i) for 0 <= i <= 16.
    func pow256_rev(i: felt) -> felt {
        let (pow256_rev_address) = get_label_location(pow256_rev_table);
        return pow256_rev_address[i];

        pow256_rev_table:
        dw 340282366920938463463374607431768211456;
        dw 1329227995784915872903807060280344576;
        dw 5192296858534827628530496329220096;
        dw 20282409603651670423947251286016;
        dw 79228162514264337593543950336;
        dw 309485009821345068724781056;
        dw 1208925819614629174706176;
        dw 4722366482869645213696;
        dw 18446744073709551616;
        dw 72057594037927936;
        dw 281474976710656;
        dw 1099511627776;
        dw 4294967296;
        dw 16777216;
        dw 65536;
        dw 256;
        dw 1;
    }

    // @notice Splits a felt into `len` bytes, big-endien, and outputs to `dst`.
    func split_word{range_check_ptr}(value: felt, len: felt, dst: felt*) {
        if (len == 0) {
            assert value = 0;
            return ();
        }
        tempvar len = len - 1;
        let output = &dst[len];
        let base = 256;
        let bound = 256;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar low_part = [output];
        assert_nn_le(low_part, 255);
        return split_word((value - low_part) / 256, len, dst);
    }

    // @notice Splits a felt into 16 bytes, big-endien, and outputs to `dst`.
    func split_word_128{range_check_ptr}(start_value: felt, dst: felt*) {
        // Fill dst using only hints with no opcodes.
        let value = start_value;
        let offset = 15;
        tempvar base = 256;
        let bound = 256;
        tempvar max = 255;

        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 0.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 1.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 2.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;
        // 3.
        let output = &dst[offset];
        let offset = offset - 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;
        let range_check_ptr = range_check_ptr + 2;
        tempvar value = (value - x) / base;

        assert value = 0;
        return ();
    }
}
