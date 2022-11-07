// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.pow import pow
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

    func bytes32_to_uint256(val: felt*) -> Uint256 {
        let res = Uint256(
            low=[val + 16] * 256 ** 15 + [val + 17] * 256 ** 14 + [val + 18] * 256 ** 13 + [val + 19] * 256 ** 12 + [val + 20] * 256 ** 11 + [val + 21] * 256 ** 10 + [val + 22] * 256 ** 9 + [val + 23] * 256 ** 8 + [val + 24] * 256 ** 7 + [val + 25] * 256 ** 6 + [val + 26] * 256 ** 5 + [val + 27] * 256 ** 4 + [val + 28] * 256 ** 3 + [val + 29] * 256 ** 2 + [val + 30] * 256 + [val + 31],
            high=[val] * 256 ** 15 + [val + 1] * 256 ** 14 + [val + 2] * 256 ** 13 + [val + 3] * 256 ** 12 + [val + 4] * 256 ** 11 + [val + 5] * 256 ** 10 + [val + 6] * 256 ** 9 + [val + 7] * 256 ** 8 + [val + 8] * 256 ** 7 + [val + 9] * 256 ** 6 + [val + 10] * 256 ** 5 + [val + 11] * 256 ** 4 + [val + 12] * 256 ** 3 + [val + 13] * 256 ** 2 + [val + 14] * 256 + [val + 15],
        );
        return res;
    }

    func bytes_i_to_uint256{range_check_ptr}(val: felt*, i: felt, res: Uint256) -> Uint256 {
        alloc_locals;
        local new_i: felt;
        local new_val: felt*;
        local high: felt;

        let is_16_le_i = is_le_felt(16, i);
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

        let is_i_le_16 = is_le_felt(new_i, 16);

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

    func bytes_to_64_bits_little_felt(bytes: felt*) -> felt {
        return [bytes + 7] * 256 ** 7 + [bytes + 6] * 256 ** 6 + [bytes + 5] * 256 ** 5 + [bytes + 4] * 256 ** 4 + [bytes + 3] * 256 ** 3 + [bytes + 2] * 256 ** 2 + [bytes + 1] * 256 + [bytes];
    }

    func fill(arr: felt*, value: felt, length: felt) {
        if (length == 0) {
            return ();
        }
        assert [arr] = value;
        return fill(arr + 1, value, length - 1);
    }

    func fill_array(fill_with: felt, input_arr: felt*, output_arr: felt*) {
        if (fill_with == 0) {
            return ();
        }
        assert [output_arr] = [input_arr];
        return fill_array(fill_with - 1, input_arr + 1, output_arr + 1);
    }

    // @notice Read and return a variable number of bytes from calldata.
    // @param self The pointer to the execution context.
    // @param offset the location from which to start reading the bytes
    // @param byte_size number of bytes to read
    // @param calldata is a pointer to the an array of 32bytes that the results will be written to
    // @return The data read from calldata
    func slice_data{range_check_ptr}(
        data_len: felt, data: felt*, data_offset: felt, slice_len: felt
    ) -> felt* {
        alloc_locals;
        local len: felt;
        let (local new_data: felt*) = alloc();

        // slice's len = min(slice_len, data_len-offset, 0)
        // which corresponds to full, partial or empty overlap with data
        // The result is zero-padded in case of partial or empty overlap.

        let is_non_empty: felt = is_le_felt(data_offset, data_len);
        let max_len: felt = (data_len - data_offset) * is_non_empty;
        let is_within_bound: felt = is_le_felt(slice_len, max_len);
        let len = max_len + (slice_len - max_len) * is_within_bound;

        memcpy(dst=new_data, src=data + data_offset, len=len);
        fill(arr=new_data + len, value=0, length=slice_len - len);
        return new_data;
    }

    func reverse(old_arr_len: felt, old_arr: felt*, new_arr_len: felt, new_arr: felt*) {
        if (old_arr_len == 0) {
            return ();
        }
        assert new_arr[old_arr_len - 1] = [old_arr];
        return reverse(old_arr_len - 1, &old_arr[1], new_arr_len + 1, new_arr);
    }

    func uint256_to_felt{range_check_ptr}(val: Uint256) -> felt {
        return val.low + val.high * 2 ** 128;
    }
}
