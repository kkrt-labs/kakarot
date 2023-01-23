// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import (
    assert_le,
    split_felt,
    assert_nn_le,
    split_int,
    unsigned_div_rem,
)
from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_and,
    uint256_check,
    uint256_eq,
    uint256_shr,
)
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

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

    // @notice This helper converts a felt straight to BigInt3
    // @param val: felt value to be converted
    // @return res: BigInt3 representation of the given input
    func to_bigint{range_check_ptr}(val: felt) -> BigInt3 {
        let val_uint256: Uint256 = to_uint256(val);
        let (res: BigInt3) = uint256_to_bigint(val_uint256);
        return res;
    }

    // @notice This helper converts a BigInt3 straight to felt
    // @param val: BigInt3 value to be converted
    // @return res: felt representation of the given input
    func bigint_to_felt{range_check_ptr}(val: BigInt3) -> felt {
        let (val_uint256: Uint256) = bigint_to_uint256(val);
        let res = uint256_to_felt(val_uint256);
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
    // @param i: sequence size.
    // @return res: Uint256 representation of the given input in bytes.
    func bytes_i_to_uint256{range_check_ptr}(val: felt*, i: felt) -> Uint256 {
        alloc_locals;

        if (i == 0) {
            let res = Uint256(0, 0);
            return res;
        }

        let is_sequence_32_bytes_or_less = is_le(i, 32);
        with_attr error_message("number must be shorter than 32 bytes") {
            assert is_sequence_32_bytes_or_less = 1;
        }

        let is_sequence_16_bytes_or_less = is_le(i, 16);

        // 1 - 16 bytes
        if (is_sequence_16_bytes_or_less != FALSE) {
            let (low) = compute_half_uint256(val=val, i=i, res=0);
            let res = Uint256(low=low, high=0);

            return res;
        }

        // 17 - 32 bytes
        let (low) = compute_half_uint256(val=val + i - 16, i=16, res=0);
        let (high) = compute_half_uint256(val=val, i=i - 16, res=0);
        let res = Uint256(low=low, high=high);

        return res;
    }

    // @notice This helper is used to convert a sequence of 32 bytes straight to BigInt3.
    // @param val: pointer to the first byte of the 32.
    // @return res: BigInt3 representation of the given input in bytes32.
    func bytes32_to_bigint{range_check_ptr}(val: felt*) -> BigInt3 {
        alloc_locals;

        let val_uint256: Uint256 = bytes32_to_uint256(val);
        let (res: BigInt3) = uint256_to_bigint(val_uint256);
        return res;
    }

    // @notice This function is used to convert a BigInt3 to straight to a bytes array represented by an array of felts (1 felt represents 1 byte).
    // @param value: BigInt3 value to convert.
    // @return: array length and felt array representation of the value.
    func bigint_to_bytes_array{range_check_ptr}(val: BigInt3) -> (
        bytes_array_len: felt, bytes_array: felt*
    ) {
        let (val_uint256: Uint256) = bigint_to_uint256(val);
        let (bytes_array_len, bytes_array) = uint256_to_bytes_array(val_uint256);
        return (bytes_array_len, bytes_array);
    }

    // @notice: This helper returns count of nonzero elements in an array
    // @param nonzeroes: count of nonzero elements in an array
    // @param idx: index that is recursively incremented of array
    // @param arr_len: length of array
    // @param arr: array whose nonzero elements are counted
    // @return nonzeroes: count of nonzero elements in an array
    func count_nonzeroes(nonzeroes: felt, idx: felt, arr_len: felt, arr: felt*) -> (
        nonzeroes: felt, index: felt, arr_len: felt, arr: felt*
    ) {
        if (idx == arr_len) {
            return (nonzeroes, idx, arr_len, arr);
        }

        let arr_element = [arr];
        let not_zero = is_not_zero(arr_element);
        let res = count_nonzeroes(nonzeroes + not_zero, idx + 1, arr_len, arr + 1);
        return res;
    }

    // @notice: This helper returns the minimal number of EVM words for a given bytes length
    // @param length: a given bytes length
    // @return res: the minimal number of EVM words
    func minimum_word_count{range_check_ptr}(length: felt) -> (res: felt) {
        let (quotient, remainder) = unsigned_div_rem(length + 31, 32);
        return (res=quotient);
    }

    func compute_half_uint256{range_check_ptr}(val: felt*, i: felt, res: felt) -> (res: felt) {
        if (i == 1) {
            return (res=res + [val]);
        }
        let (temp_pow) = pow(256, i - 1);
        let (res) = compute_half_uint256(val + 1, i - 1, res + [val] * temp_pow);
        return (res=res);
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
        uint256_check(val);
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

    // @notice This function is a variant of `uint256_to_bytes_array` that encodes the uint256 with no padding
    // @param value: value to convert.
    // @param idx: index of res array
    // @param res: resultant encoded bytearray, but in reverse order
    // @param dest: reversed res, putting byte array in right order
    // @return bytes array len
    func uint256_to_bytes_no_padding{bitwise_ptr: BitwiseBuiltin*, range_check_ptr}(
        value: Uint256, idx: felt, res: felt*, dest: felt*
    ) -> (bytes_len: felt) {
        alloc_locals;
        let (is_zero) = uint256_eq(value, Uint256(0, 0));
        if (is_zero == 1) {
            reverse(old_arr_len=idx, old_arr=res - idx, new_arr_len=idx, new_arr=dest);
            return (bytes_len=idx);
        }
        let (byte_uint256) = uint256_and(value, Uint256(low=255, high=0));
        let byte = uint256_to_felt(byte_uint256);
        assert [res] = byte;  // get the last 8 bits of the value
        let (val_shifted_one_byte) = uint256_shr(value, Uint256(low=8, high=0));
        let (bytes_len) = uint256_to_bytes_no_padding(val_shifted_one_byte, idx + 1, res + 1, dest);  // recursively call function with value shifted right by 8 bits
        return (bytes_len=bytes_len);
    }

    // @notice This function is like `uint256_to_bytes_array` except it writes the byte array to a given destination with the given offset and length
    // @param value: value to convert.
    // @param byte_array_offset: The starting offset of byte array that is copied to the destination array.
    // @param byte_array_len: The length of byte array that is copied to the destination array.
    // @param dest_offset: The offset of the destination array that the byte array is copied.
    // @param dest_len: The length of the destination array.
    // @param dest: The destination array
    // @return: array length and felt array representation of the value.
    func uint256_to_dest_bytes_array{range_check_ptr}(
        value: Uint256,
        byte_array_offset: felt,
        byte_array_len: felt,
        dest_offset: felt,
        dest_len: felt,
        dest: felt*,
    ) -> (updated_dest_len: felt) {
        alloc_locals;
        let (_, bytes_array) = uint256_to_bytes_array(value);
        memcpy(dst=dest + dest_offset, src=bytes_array + byte_array_offset, len=byte_array_len);
        return (updated_dest_len=dest_len + byte_array_len);
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

    // @notice Load sequences of 8 bytes little endian into an array of felts
    // @param len: final length of the output.
    // @param input: pointer to bytes array input.
    // @param output: pointer to bytes array output.
    func load_64_bits_array(len: felt, input: felt*, output: felt*) {
        if (len == 0) {
            return ();
        }
        let loaded = bytes_to_64_bits_little_felt(input);
        assert [output] = loaded;
        return load_64_bits_array(len - 1, input + 8, output + 1);
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

    // @notice Splits a felt into `len` bytes, big-endian, and outputs to `dst`.
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

    // @notice Splits a felt into `len` bytes, little-endian, and outputs to `dst`.
    func split_word_little{range_check_ptr}(value: felt, len: felt, dst: felt*) {
        if (len == 0) {
            assert value = 0;
            return ();
        }
        let output = &dst[0];
        let base = 256;
        let bound = 256;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar low_part = [output];
        assert_nn_le(low_part, 255);
        return split_word_little((value - low_part) / 256, len - 1, dst + 1);
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

    // @notice Ceil a number of bits to the next word (32 bytes)
    // ex: ceil_bytes_len_to_next_32_bytes_word(2) = 32
    // ex: ceil_bytes_len_to_next_32_bytes_word(34) = 64
    func ceil_bytes_len_to_next_32_bytes_word{range_check_ptr}(bytes_len: felt) -> felt {
        let (q, _) = unsigned_div_rem(bytes_len + 31, 32);
        return q * 32;
    }

    // @notice Returns the min value between a and b
    func min{range_check_ptr}(a: felt, b: felt) -> felt {
        if (is_le(a, b) == 0) {
            return b;
        } else {
            return a;
        }
    }

    // @notice convert bytes to little endian
    func bytes_to_bytes8_little_endian{range_check_ptr}(
        bytes_len: felt,
        bytes: felt*,
        index: felt,
        size: felt,
        bytes8: felt,
        bytes8_shift: felt,
        dest: felt*,
        dest_index: felt,
    ) {
        alloc_locals;
        if (index == size) {
            return ();
        }

        local current_byte;
        let out_of_bound = is_le(a=bytes_len, b=index);
        if (out_of_bound != FALSE) {
            current_byte = 0;
        } else {
            assert current_byte = [bytes + index];
        }

        let (pow256_address) = get_label_location(pow256_table);
        let bit_shift = pow256_address[bytes8_shift];

        let _bytes8 = bytes8 + bit_shift * current_byte;

        let bytes8_full = is_le(a=7, b=bytes8_shift);
        let end_of_loop = is_le(size, index + 1);
        let write_to_dest = is_le(1, bytes8_full + end_of_loop);
        if (write_to_dest != FALSE) {
            assert dest[dest_index] = _bytes8;
            return bytes_to_bytes8_little_endian(
                bytes_len, bytes, index + 1, size, 0, 0, dest, dest_index + 1
            );
        }
        return bytes_to_bytes8_little_endian(
            bytes_len, bytes, index + 1, size, _bytes8, bytes8_shift + 1, dest, dest_index
        );

        pow256_table:
        dw 1;
        dw 256;
        dw 65536;
        dw 16777216;
        dw 4294967296;
        dw 1099511627776;
        dw 281474976710656;
        dw 72057594037927936;
    }

    // @notice transform a felt to big endian bytes
    // @param value The initial felt
    // @param bytes_len The number of bytes (used for recursion, set to 0)
    // @param bytes The pointer to the bytes
    // @return bytes_len The final length of the bytes array
    func felt_to_bytes{range_check_ptr}(value: felt, bytes_len: felt, bytes: felt*) -> (
        bytes_len: felt
    ) {
        let (q, r) = unsigned_div_rem(value, 256);
        let is_le_256 = is_le(r, 256);
        if (is_le_256 != FALSE) {
            assert [bytes] = value;
            return (bytes_len=bytes_len + 1);
        } else {
            assert [bytes] = r;
            return felt_to_bytes(value=q, bytes_len=bytes_len + 1, bytes=bytes + 1);
        }
    }

    // @notice transform muliple bytes into a single felt
    // @param data_len The length of the bytes
    // @param data The pointer to the bytes array
    // @param n used for recursion, set to 0
    // @return n the resultant felt
    func bytes_to_felt{range_check_ptr}(data_len: felt, data: felt*, n: felt) -> (n: felt) {
        if (data_len == 0) {
            return (n=n);
        }
        let e: felt = data_len - 1;
        let byte: felt = data[data_len - 1];
        let (res) = pow(256, e);
        return bytes_to_felt(data_len=data_len - 1, data=data, n=n + byte * res);
    }

    // @notice Transforms a keccak hash to an ethereum address by taking last 20 bytes
    // @param hash - The keccak hash.
    // @return address - The address.
    func keccak_hash_to_evm_contract_address{range_check_ptr}(hash: Uint256) -> felt {
        let (_, r) = unsigned_div_rem(hash.high, 256 ** 4);
        let address = hash.low + r * 2 ** 128;
        return address;
    }

    // @notice transform muliple bytes into words of 32 bits (big endian)
    // @dev the input data must have length in multiples of 4
    // @dev you may use the function `fill` to pad it with zeros
    // @param data_len The length of the bytes
    // @param data The pointer to the bytes array
    // @param n_len used for recursion, set to 0
    // @param n used for recursion, set to pointer
    // @return n_len the resulting array length
    // @return n the resulting array
    func bytes_to_words_32bit_array{range_check_ptr}(
        data_len: felt, data: felt*, n_len: felt, n: felt*
    ) -> (n_len: felt, n: felt*) {
        alloc_locals;
        if (data_len == 0) {
            return (n_len=n_len, n=n);
        }

        let (_, r) = unsigned_div_rem(data_len, 4);
        with_attr error_message("data length must be multiple of 4") {
            assert r = 0;
        }

        // Load sequence of 4 bytes into a single 32-bit word (big endian)
        let res = load_word(4, data);
        assert n[n_len] = res;
        return bytes_to_words_32bit_array(
            data_len=data_len - 4, data=data + 4, n_len=n_len + 1, n=n
        );
    }

    // @notice transform array of 32-bit words (big endian) into a bytes array
    // @param data_len The length of the 32-bit array
    // @param data The pointer to the 32-bit array
    // @param bytes_len used for recursion, set to 0
    // @param bytes used for recursion, set to pointer
    // @return bytes_len the resulting array length
    // @return bytes the resulting array
    func words_32bit_to_bytes_array{range_check_ptr}(
        data_len: felt, data: felt*, bytes_len: felt, bytes: felt*
    ) -> (bytes_len: felt, bytes: felt*) {
        alloc_locals;
        if (data_len == 0) {
            return (bytes_len=bytes_len, bytes=bytes);
        }

        // Split a 32-bit big endian word into 4 bytes
        // Store result in a temporary array
        let (temp: felt*) = alloc();
        split_word([data], 4, temp);

        // Append temp array to bytes array
        let (local res: felt*) = alloc();
        memcpy(res, bytes, bytes_len);
        memcpy(res + bytes_len, temp, 4);

        return words_32bit_to_bytes_array(
            data_len=data_len - 1, data=data + 1, bytes_len=bytes_len + 4, bytes=res
        );
    }
}
