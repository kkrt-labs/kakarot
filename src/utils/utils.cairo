// SPDX-License-Identifier: MIT

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le, split_felt, assert_nn_le
from starkware.cairo.common.math_cmp import is_nn, is_not_zero
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update
from starkware.starknet.common.syscalls import get_tx_info

from kakarot.model import model
from utils.bytes import uint256_to_bytes32, felt_to_bytes32
from utils.maths import unsigned_div_rem

// @title Helper Functions
// @notice This file contains a selection of helper function that simplify tasks such as type conversion and bit manipulation
namespace Helpers {
    // Returns 1 if value == 0. Returns 0 otherwise.
    @known_ap_change
    func is_zero(value) -> felt {
        if (value == 0) {
            return 1;
        }

        return 0;
    }

    // @notice Performs subtraction and returns 0 if the result is negative.
    func saturated_sub{range_check_ptr}(a, b) -> felt {
        let res = a - b;
        let is_res_nn = is_nn(res);
        if (is_res_nn != FALSE) {
            return res;
        }
        return 0;
    }

    func to_uint256{range_check_ptr}(val: felt) -> Uint256* {
        let (high, low) = split_felt(val);
        tempvar res = new Uint256(low, high);
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
        let low = [val + 16] * 256 ** 15;
        let low = low + [val + 17] * 256 ** 14;
        let low = low + [val + 18] * 256 ** 13;
        let low = low + [val + 19] * 256 ** 12;
        let low = low + [val + 20] * 256 ** 11;
        let low = low + [val + 21] * 256 ** 10;
        let low = low + [val + 22] * 256 ** 9;
        let low = low + [val + 23] * 256 ** 8;
        let low = low + [val + 24] * 256 ** 7;
        let low = low + [val + 25] * 256 ** 6;
        let low = low + [val + 26] * 256 ** 5;
        let low = low + [val + 27] * 256 ** 4;
        let low = low + [val + 28] * 256 ** 3;
        let low = low + [val + 29] * 256 ** 2;
        let low = low + [val + 30] * 256 ** 1;
        let low = low + [val + 31];
        let high = [val] * 256 ** 1 * 256 ** 14;
        let high = high + [val + 1] * 256 ** 14;
        let high = high + [val + 2] * 256 ** 13;
        let high = high + [val + 3] * 256 ** 12;
        let high = high + [val + 4] * 256 ** 11;
        let high = high + [val + 5] * 256 ** 10;
        let high = high + [val + 6] * 256 ** 9;
        let high = high + [val + 7] * 256 ** 8;
        let high = high + [val + 8] * 256 ** 7;
        let high = high + [val + 9] * 256 ** 6;
        let high = high + [val + 10] * 256 ** 5;
        let high = high + [val + 11] * 256 ** 4;
        let high = high + [val + 12] * 256 ** 3;
        let high = high + [val + 13] * 256 ** 2;
        let high = high + [val + 14] * 256;
        let high = high + [val + 15];
        let res = Uint256(low=low, high=high);
        return res;
    }
    // @notice This function is used to convert bytes array in big-endian to Uint256.
    // @dev The function is limited to 32 bytes or less.
    // @param bytes_len: bytes array length.
    // @param bytes: pointer to the first byte of the bytes array.
    // @return res: Uint256 representation of the given input in bytes.
    func bytes_to_uint256{range_check_ptr}(bytes_len: felt, bytes: felt*) -> Uint256 {
        alloc_locals;

        if (bytes_len == 0) {
            let res = Uint256(0, 0);
            return res;
        }

        let is_bytes_len_16_bytes_or_less = is_nn(16 - bytes_len);

        // 1 - 16 bytes
        if (is_bytes_len_16_bytes_or_less != FALSE) {
            let low = bytes_to_felt(bytes_len, bytes);
            let res = Uint256(low=low, high=0);

            return res;
        }

        // 17 - 32 bytes
        let low = bytes_to_felt(16, bytes + bytes_len - 16);
        let high = bytes_to_felt(bytes_len - 16, bytes);
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
        alloc_locals;
        let (val_uint256: Uint256) = bigint_to_uint256(val);
        let (bytes: felt*) = alloc();
        uint256_to_bytes32(bytes, val_uint256);
        return (32, bytes);
    }

    // @notice: This helper returns the minimal number of EVM words for a given bytes length
    // @param length: a given bytes length
    // @return res: the minimal number of EVM words
    func minimum_word_count{range_check_ptr}(length: felt) -> (res: felt) {
        let (quotient, remainder) = unsigned_div_rem(length + 31, 32);
        return (res=quotient);
    }

    // @notice This function is used to convert a sequence of 8 bytes to a felt.
    // @param val: pointer to the first byte.
    // @return: felt representation of the input.
    func bytes_to_64_bits_little_felt(bytes: felt*) -> felt {
        let res = [bytes + 7] * 256 ** 7;
        let res = res + [bytes + 6] * 256 ** 6;
        let res = res + [bytes + 5] * 256 ** 5;
        let res = res + [bytes + 4] * 256 ** 4;
        let res = res + [bytes + 3] * 256 ** 3;
        let res = res + [bytes + 2] * 256 ** 2;
        let res = res + [bytes + 1] * 256;
        let res = res + [bytes];
        return res;
    }

    // @notice This function is used to convert a uint256 to a felt.
    // @param val: value to convert.
    // @return: felt representation of the input.
    func uint256_to_felt{range_check_ptr}(val: Uint256) -> felt {
        [range_check_ptr] = val.low;
        [range_check_ptr + 1] = val.high;
        let range_check_ptr = range_check_ptr + 2;
        return val.low + val.high * 2 ** 128;
    }

    // @notice Loads a sequence of bytes into a single felt in big-endian.
    // @param len: number of bytes.
    // @param ptr: pointer to bytes array.
    // @return: packed felt.
    func bytes_to_felt(len: felt, ptr: felt*) -> felt {
        if (len == 0) {
            return 0;
        }
        tempvar current = 0;

        // len, ptr, ?, ?, current
        // ?, ? are intermediate steps created by the compiler to unfold the
        // complex expression.
        loop:
        let len = [ap - 5];
        let ptr = cast([ap - 4], felt*);
        let current = [ap - 1];

        tempvar len = len - 1;
        tempvar ptr = ptr + 1;
        tempvar current = current * 256 + [ptr - 1];

        static_assert len == [ap - 5];
        static_assert ptr == [ap - 4];
        static_assert current == [ap - 1];
        jmp loop if len != 0;

        return current;
    }

    func try_parse_destination_from_bytes(bytes_len: felt, bytes: felt*) -> model.Option {
        if (bytes_len != 20) {
            with_attr error_message("Bytes has length {bytes_len}, expected 0 or 20") {
                assert bytes_len = 0;
            }
            let res = model.Option(is_some=0, value=0);
            return res;
        }
        let address = bytes20_to_felt(bytes);
        let res = model.Option(is_some=1, value=address);
        return res;
    }

    // @notice This function is used to convert a sequence of 4 bytes big-endian
    // to a felt.
    // @param val: pointer to the first byte of the 4.
    // @return res: felt representation of the given input in bytes4.
    func bytes4_to_felt(val: felt*) -> felt {
        let current = [val] * 256 ** 3;
        let current = current + [val + 1] * 256 ** 2;
        let current = current + [val + 2] * 256;
        let current = current + [val + 3];
        return current;
    }

    // @notice This function is used to convert a sequence of 20 bytes big-endian
    // to felt.
    // @param val: pointer to the first byte of the 20.
    // @return res: felt representation of the given input in bytes20.
    func bytes20_to_felt(val: felt*) -> felt {
        let current = [val] * 256 ** 19;
        let current = current + [val + 1] * 256 ** 18;
        let current = current + [val + 2] * 256 ** 17;
        let current = current + [val + 3] * 256 ** 16;
        let current = current + [val + 4] * 256 ** 15;
        let current = current + [val + 5] * 256 ** 14;
        let current = current + [val + 6] * 256 ** 13;
        let current = current + [val + 7] * 256 ** 12;
        let current = current + [val + 8] * 256 ** 11;
        let current = current + [val + 9] * 256 ** 10;
        let current = current + [val + 10] * 256 ** 9;
        let current = current + [val + 11] * 256 ** 8;
        let current = current + [val + 12] * 256 ** 7;
        let current = current + [val + 13] * 256 ** 6;
        let current = current + [val + 14] * 256 ** 5;
        let current = current + [val + 15] * 256 ** 4;
        let current = current + [val + 16] * 256 ** 3;
        let current = current + [val + 17] * 256 ** 2;
        let current = current + [val + 18] * 256 ** 1;
        let current = current + [val + 19];
        return current;
    }

    // @notice This function is used to convert a sequence of 32 bytes big-endian
    // to a felt.
    // @dev If the value doesn't fit in a felt, the value will be wrapped around.
    // @param val: pointer to the first byte of the 32.
    // @return res: felt representation of the given input in bytes32.
    @known_ap_change
    func bytes32_to_felt(val: felt*) -> felt {
        let current = [val] * 256 ** 31;
        let current = current + [val + 1] * 256 ** 30;
        let current = current + [val + 2] * 256 ** 29;
        let current = current + [val + 3] * 256 ** 28;
        let current = current + [val + 4] * 256 ** 27;
        let current = current + [val + 5] * 256 ** 26;
        let current = current + [val + 6] * 256 ** 25;
        let current = current + [val + 7] * 256 ** 24;
        let current = current + [val + 8] * 256 ** 23;
        let current = current + [val + 9] * 256 ** 22;
        let current = current + [val + 10] * 256 ** 21;
        let current = current + [val + 11] * 256 ** 20;
        let current = current + [val + 12] * 256 ** 19;
        let current = current + [val + 13] * 256 ** 18;
        let current = current + [val + 14] * 256 ** 17;
        let current = current + [val + 15] * 256 ** 16;
        let current = current + [val + 16] * 256 ** 15;
        let current = current + [val + 17] * 256 ** 14;
        let current = current + [val + 18] * 256 ** 13;
        let current = current + [val + 19] * 256 ** 12;
        let current = current + [val + 20] * 256 ** 11;
        let current = current + [val + 21] * 256 ** 10;
        let current = current + [val + 22] * 256 ** 9;
        let current = current + [val + 23] * 256 ** 8;
        let current = current + [val + 24] * 256 ** 7;
        let current = current + [val + 25] * 256 ** 6;
        let current = current + [val + 26] * 256 ** 5;
        let current = current + [val + 27] * 256 ** 4;
        let current = current + [val + 28] * 256 ** 3;
        let current = current + [val + 29] * 256 ** 2;
        let current = current + [val + 30] * 256 ** 1;
        let current = current + [val + 31];
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

    // @notice Load sequence of 32 bytes into an array of felts
    // @dev If the input doesn't fit in a felt, the value will be wrapped around.
    // @param input_len: The number of bytes in the input.
    // @param input: pointer to bytes array input.
    // @param output: pointer to bytes array output.
    func load_256_bits_array(input_len: felt, input: felt*) -> (output_len: felt, output: felt*) {
        alloc_locals;
        let (local output_start) = alloc();
        if (input_len == 0) {
            return (0, output_start);
        }

        tempvar ptr = input;
        tempvar output = output_start;
        tempvar remaining = input_len;

        loop:
        let ptr = cast([ap - 3], felt*);
        let output = cast([ap - 2], felt*);
        let remaining = [ap - 1];

        let loaded = bytes32_to_felt(ptr);
        assert [output] = loaded;

        tempvar ptr = ptr + 32;
        tempvar output = output + 1;
        tempvar remaining = remaining - 32;

        static_assert ptr == [ap - 3];
        static_assert output == [ap - 2];
        static_assert remaining == [ap - 1];
        jmp loop if remaining != 0;

        let output_len = output - output_start;
        return (output_len, output_start);
    }

    // @notice Converts an array of felt to an array of bytes.
    // @dev Each input felt is converted to 32 bytes.
    // @param input_len: The number of felts in the input.
    // @param input: pointer to the input array.
    // @param output: pointer to the output array.
    func felt_array_to_bytes32_array{range_check_ptr}(
        input_len: felt, input: felt*, output: felt*
    ) {
        if (input_len == 0) {
            return ();
        }
        felt_to_bytes32(output, [input]);
        return felt_array_to_bytes32_array(input_len - 1, input + 1, output + 32);
    }

    // @notice Divides a 128-bit number with remainder.
    // @dev This is almost identical to cairo.common.math.unsigned_dev_rem, but supports the case
    // @dev of div == 2**128 as well. assert_le is also inlined.
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

        // equivalent to assert_le(r, div - 1);
        tempvar a = div - 1 - r;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        a = [range_check_ptr];
        let range_check_ptr = range_check_ptr + 1;

        assert value = q * div + r;
        return (q, r);
    }

    // @notice Computes 256 ** (16 - i) for 0 <= i <= 16.
    func pow256_rev(i: felt) -> felt {
        let (pow256_rev_address) = get_label_location(pow256_rev_table);
        return pow256_rev_address[i];

        pow256_rev_table:
        dw 256 ** 16;
        dw 256 ** 15;
        dw 256 ** 14;
        dw 256 ** 13;
        dw 256 ** 12;
        dw 256 ** 11;
        dw 256 ** 10;
        dw 256 ** 9;
        dw 256 ** 8;
        dw 256 ** 7;
        dw 256 ** 6;
        dw 256 ** 5;
        dw 256 ** 4;
        dw 256 ** 3;
        dw 256 ** 2;
        dw 256 ** 1;
        dw 256 ** 0;
    }

    // @notice Splits a felt into `len` bytes, big-endian, and outputs to `dst`.
    func split_word{range_check_ptr}(value: felt, len: felt, dst: felt*) {
        if (len == 0) {
            with_attr error_message("value not empty") {
                assert value = 0;
            }
            return ();
        }
        with_attr error_message("len must be < 32") {
            assert is_nn(31 - len) = TRUE;
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
            with_attr error_message("value not empty") {
                assert value = 0;
            }
            return ();
        }
        with_attr error_message("len must be < 32") {
            assert is_nn(31 - len) = TRUE;
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

    // @notice Splits a felt into 16 bytes, big-endian, and outputs to `dst`.
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

    // @notice Calculates the number of bytes used by a 128-bit value.
    // @param value The 128-bit value.
    // @return The number of bytes used by the value.
    func bytes_used_128{range_check_ptr}(value: felt) -> felt {
        let (q, r) = unsigned_div_rem(value, 256 ** 15);
        if (q != 0) {
            return 16;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 14);
        if (q != 0) {
            return 15;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 13);
        if (q != 0) {
            return 14;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 12);
        if (q != 0) {
            return 13;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 11);
        if (q != 0) {
            return 12;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 10);
        if (q != 0) {
            return 11;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 9);
        if (q != 0) {
            return 10;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 8);
        if (q != 0) {
            return 9;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 7);
        if (q != 0) {
            return 8;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 6);
        if (q != 0) {
            return 7;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 5);
        if (q != 0) {
            return 6;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 4);
        if (q != 0) {
            return 5;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 3);
        if (q != 0) {
            return 4;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 2);
        if (q != 0) {
            return 3;
        }
        let (q, r) = unsigned_div_rem(value, 256 ** 1);
        if (q != 0) {
            return 2;
        }
        if (value != 0) {
            return 1;
        }
        return 0;
    }

    // @notice transform multiple bytes into words of 32 bits (big endian)
    // @dev the input data must have length in multiples of 4
    // @param data_len The length of the bytes
    // @param data The pointer to the bytes array
    // @param n_len used for recursion, set to 0
    // @param n used for recursion, set to pointer
    // @return n_len the resulting array length
    // @return n the resulting array
    func bytes_to_bytes4_array{range_check_ptr}(
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
        let res = bytes_to_felt(4, data);
        assert n[n_len] = res;
        return bytes_to_bytes4_array(data_len=data_len - 4, data=data + 4, n_len=n_len + 1, n=n);
    }

    // @notice transform array of 32-bit words (big endian) into a bytes array
    // @param data_len The length of the 32-bit array
    // @param data The pointer to the 32-bit array
    // @param bytes_len used for recursion, set to 0
    // @param bytes used for recursion, set to pointer
    // @return bytes_len the resulting array length
    // @return bytes the resulting array
    func bytes4_array_to_bytes{range_check_ptr}(
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

        return bytes4_array_to_bytes(
            data_len=data_len - 1, data=data + 1, bytes_len=bytes_len + 4, bytes=res
        );
    }
    // Returns 1 if lhs <= rhs (or more precisely 0 <= rhs - lhs < RANGE_CHECK_BOUND).
    // Returns 0 otherwise.
    // Soundness assumptions (caller responsibility to ensure those) :
    // - 0 <= lhs < RANGE_CHECK_BOUND
    // - 0 <= rhs < RANGE_CHECK_BOUND
    @known_ap_change
    func is_le_unchecked{range_check_ptr}(lhs: felt, rhs: felt) -> felt {
        tempvar a = rhs - lhs;  // reference (rhs-lhs) as "a" to use already whitelisted hint
        %{ memory[ap] = 0 if 0 <= (ids.a % PRIME) < range_check_builtin.bound else 1 %}
        jmp false if [ap] != 0, ap++;

        // Ensure lhs <= rhs
        assert [range_check_ptr] = a;
        ap += 2;  // Two memory holes for known_ap_change in case of false case: Two instructions more: -1*a, and (-1*a) - 1.
        tempvar range_check_ptr = range_check_ptr + 1;
        tempvar res = 1;
        ret;

        false:
        // Ensure rhs < lhs
        assert [range_check_ptr] = (-a) - 1;
        tempvar range_check_ptr = range_check_ptr + 1;
        tempvar res = 0;
        ret;
    }

    // @notice Initializes a dictionary of valid jump destinations in EVM bytecode.
    // @param bytecode_len The length of the bytecode.
    // @param bytecode The EVM bytecode to analyze.
    // @return (valid_jumpdests_start, valid_jumpdests) The starting and ending pointers of the valid jump destinations.
    //
    // @dev This function iterates over the bytecode from the current index 'i'.
    // If the opcode at the current index is between 0x5f and 0x7f (PUSHN opcodes) (inclusive),
    // it skips the next 'n_args' opcodes, where 'n_args' is the opcode minus 0x5f.
    // If the opcode is 0x5b (JUMPDEST), it marks the current index as a valid jump destination.
    // It continues by jumping back to the body flag until it has processed the entire bytecode.
    func initialize_jumpdests{range_check_ptr}(bytecode_len: felt, bytecode: felt*) -> (
        valid_jumpdests_start: DictAccess*, valid_jumpdests: DictAccess*
    ) {
        alloc_locals;
        let (local valid_jumpdests_start: DictAccess*) = default_dict_new(0);
        tempvar range_check_ptr = range_check_ptr;
        tempvar valid_jumpdests = valid_jumpdests_start;
        tempvar i = 0;
        jmp body if bytecode_len != 0;

        static_assert range_check_ptr == [ap - 3];
        jmp end;

        body:
        let bytecode_len = [fp - 4];
        let bytecode = cast([fp - 3], felt*);
        let range_check_ptr = [ap - 3];
        let valid_jumpdests = cast([ap - 2], DictAccess*);
        let i = [ap - 1];

        tempvar opcode = [bytecode + i];
        let is_opcode_ge_0x5f = Helpers.is_le_unchecked(0x5f, opcode);
        let is_opcode_le_0x7f = Helpers.is_le_unchecked(opcode, 0x7f);
        let is_push_opcode = is_opcode_ge_0x5f * is_opcode_le_0x7f;
        let next_i = i + 1 + is_push_opcode * (opcode - 0x5f);  // 0x5f is the first PUSHN opcode, opcode - 0x5f is the number of arguments.

        if (opcode == 0x5b) {
            dict_write{dict_ptr=valid_jumpdests}(i, TRUE);
            tempvar valid_jumpdests = valid_jumpdests;
            tempvar next_i = next_i;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar valid_jumpdests = valid_jumpdests;
            tempvar next_i = next_i;
            tempvar range_check_ptr = range_check_ptr;
        }

        // continue_loop != 0 => next_i - bytecode_len < 0 <=> next_i < bytecode_len
        tempvar a = next_i - bytecode_len;
        %{ memory[ap] = 0 if 0 <= (ids.a % PRIME) < range_check_builtin.bound else 1 %}
        ap += 1;
        let continue_loop = [ap - 1];
        tempvar range_check_ptr = range_check_ptr;
        tempvar valid_jumpdests = valid_jumpdests;
        tempvar i = next_i;
        static_assert range_check_ptr == [ap - 3];
        static_assert valid_jumpdests == [ap - 2];
        static_assert i == [ap - 1];
        jmp body if continue_loop != 0;

        end:
        let range_check_ptr = [ap - 3];
        let i = [ap - 1];
        // Verify that i >= bytecode_len to ensure loop terminated correctly.
        let check = Helpers.is_le_unchecked(bytecode_len, i);
        assert check = 1;
        return (valid_jumpdests_start, valid_jumpdests);
    }

    const BYTES_PER_FELT = 31;

    // @notice Load packed bytes from an array of bytes packed in 31-byte words and a final word.
    // @param input_len The total amount of bytes in the array.
    // @param input The input, an array of 31-bytes words and a final word.
    // @param bytes_len The total amount of bytes to load.
    // @returns bytes An array of individual bytes loaded from the packed input.
    func load_packed_bytes{range_check_ptr}(input_len: felt, input: felt*, bytes_len: felt) -> (
        bytes: felt*
    ) {
        alloc_locals;

        let (local bytes: felt*) = alloc();
        if (bytes_len == 0) {
            return (bytes=bytes);
        }

        local bound = 256;
        local base = 256;
        let (local chunk_counts, local remainder) = unsigned_div_rem(bytes_len, BYTES_PER_FELT);

        tempvar remaining_bytes = bytes_len;
        tempvar range_check_ptr = range_check_ptr;
        tempvar index = 0;
        tempvar value = 0;
        tempvar count = 0;

        read:
        let remaining_bytes = [ap - 5];
        let range_check_ptr = [ap - 4];
        let index = [ap - 3];
        let value = [ap - 2];
        let count = [ap - 1];
        let input = cast([fp - 4], felt*);

        tempvar value = input[index];

        let chunk_counts = [fp + 3];
        let remainder = [fp + 4];

        tempvar remaining_chunk = chunk_counts - index;
        jmp full_chunk if remaining_chunk != 0;
        tempvar count = remainder;
        jmp next;

        full_chunk:
        tempvar count = BYTES_PER_FELT;

        next:
        tempvar remaining_bytes = remaining_bytes;
        tempvar range_check_ptr = range_check_ptr;
        tempvar index = index + 1;
        tempvar value = value;
        tempvar count = count;

        body:
        let remaining_bytes = [ap - 5];
        let range_check_ptr = [ap - 4];
        let index = [ap - 3];
        let value = [ap - 2];
        let count = [ap - 1];

        let bytes = cast([fp], felt*);
        let bound = [fp + 1];
        let base = [fp + 2];

        tempvar offset = (index - 1) * BYTES_PER_FELT + count - 1;
        let output = bytes + offset;

        // Put byte in output and assert that 0 <= byte < bound
        // See math.split_int
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar a = [output];
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr];
        tempvar a = bound - 1 - a;
        %{
            from starkware.cairo.common.math_utils import assert_integer
            assert_integer(ids.a)
            assert 0 <= ids.a % PRIME < range_check_builtin.bound, f'a = {ids.a} is out of range.'
        %}
        assert a = [range_check_ptr + 1];

        tempvar value = (value - [output]) / base;
        tempvar remaining_bytes = remaining_bytes - 1;
        tempvar range_check_ptr = range_check_ptr + 2;
        tempvar index = index;
        tempvar value = value;
        tempvar count = count - 1;

        jmp cond if remaining_bytes != 0;

        with_attr error_message("Value is not empty") {
            assert value = 0;
        }
        let bytes = cast([fp], felt*);
        return (bytes=bytes);

        cond:
        jmp body if count != 0;
        with_attr error_message("Value is not empty") {
            assert value = 0;
        }
        jmp read;
    }

    // @notice Ensure the tx is a view call
    // @dev Verify tx fields are empty except for chain_id
    func assert_view_call{syscall_ptr: felt*}() -> () {
        let (tx_info) = get_tx_info();
        with_attr error_message("Only view call") {
            assert tx_info.version = 0;
            assert tx_info.account_contract_address = 0;
            assert tx_info.max_fee = 0;
            assert tx_info.signature_len = 0;
            assert tx_info.transaction_hash = 0;
            assert is_not_zero(tx_info.chain_id) = 1;
            assert tx_info.nonce = 0;
        }
        return ();
    }
}
