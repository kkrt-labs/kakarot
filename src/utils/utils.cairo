// SPDX-License-Identifier: MIT

// StarkWare dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_le, split_felt, assert_nn_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.hash_state import hash_finalize, hash_init, hash_update

from kakarot.model import model
from utils.bytes import uint256_to_bytes32

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
    // @param bytes_len: bytes array length.
    // @param bytes: pointer to the first byte of the bytes array.
    // @return res: Uint256 representation of the given input in bytes.
    func bytes_big_endian_to_uint256{range_check_ptr}(bytes_len: felt, bytes: felt*) -> Uint256 {
        alloc_locals;

        if (bytes_len == 0) {
            let res = Uint256(0, 0);
            return res;
        }

        let is_bytes_len_32_bytes_or_less = is_le(bytes_len, 32);
        with_attr error_message("number must be shorter than 32 bytes") {
            assert is_bytes_len_32_bytes_or_less = 1;
        }

        let is_bytes_len_16_bytes_or_less = is_le(bytes_len, 16);

        // 1 - 16 bytes
        if (is_bytes_len_16_bytes_or_less == TRUE) {
            let (low) = compute_half_uint256_from_bytes(bytes_len, bytes, 0);
            let res = Uint256(low=low, high=0);

            return res;
        }

        // 17 - 32 bytes
        let (low) = compute_half_uint256_from_bytes(16, bytes + bytes_len - 16, 0);
        let (high) = compute_half_uint256_from_bytes(bytes_len - 16, bytes, 0);
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

    func compute_half_uint256_from_bytes{range_check_ptr}(
        bytes_len: felt, bytes: felt*, res: felt
    ) -> (res: felt) {
        if (bytes_len == 1) {
            return (res=res + [bytes]);
        }
        let temp_pow = pow256_rev(16 - (bytes_len - 1));
        let (res) = compute_half_uint256_from_bytes(
            bytes_len - 1, bytes + 1, res + [bytes] * temp_pow
        );
        return (res=res);
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
        uint256_check(val);
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
            let res = model.Option(is_some=0, value=0);
            return res;
        }
        let address = bytes20_to_felt(bytes);
        let res = model.Option(is_some=1, value=address);
        return res;
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
        tempvar base = 256 ** 15;
        let bound = base;
        tempvar max = base - 1;
        let (output) = alloc();

        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 16;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 1.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 15;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 2.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 14;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 3.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 13;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 0.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 12;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 1.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 11;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 2.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 10;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 3.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 9;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 0.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 8;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 1.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 7;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 2.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 6;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 3.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 5;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 0.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 4;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 1.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 3;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 2.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
            return 2;
        }
        tempvar base = base / 256;
        let bound = base;
        tempvar max = base - 1;
        // 3.
        let output = output + 1;
        %{
            memory[ids.output] = res = (int(ids.value) % PRIME) % ids.base
            assert res < ids.bound, f'split_int(): Limb {res} is out of range.'
        %}
        tempvar x = [output];
        [range_check_ptr] = x;
        assert [range_check_ptr + 1] = max - x;

        let range_check_ptr = range_check_ptr + 2;
        if (value - x != 0) {
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
}
