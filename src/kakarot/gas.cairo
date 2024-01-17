from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_lt

from kakarot.model import model

namespace Gas {
    const JUMPDEST = 1;
    const BASE = 2;
    const VERY_LOW = 3;
    const STORAGE_SET = 20000;
    const STORAGE_UPDATE = 5000;
    const STORAGE_CLEAR_REFUND = 4800;
    const LOW = 5;
    const MID = 8;
    const HIGH = 10;
    const EXPONENTIATION = 10;
    const EXPONENTIATION_PER_BYTE = 50;
    const MEMORY = 3;
    const KECCAK256 = 30;
    const KECCAK256_WORD = 6;
    const COPY = 3;
    const BLOCK_HASH = 20;
    const LOG = 375;
    const LOG_DATA = 8;
    const LOG_TOPIC = 375;
    const CREATE = 32000;
    const CODE_DEPOSIT = 200;
    const ZERO = 0;
    const NEW_ACCOUNT = 25000;
    const CALL_VALUE = 9000;
    const CALL_STIPEND = 2300;
    const SELF_DESTRUCT = 5000;
    const SELF_DESTRUCT_NEW_ACCOUNT = 25000;
    const ECRECOVER = 3000;
    const SHA256 = 60;
    const SHA256_WORD = 12;
    const RIPEMD160 = 600;
    const RIPEMD160_WORD = 120;
    const IDENTITY = 15;
    const IDENTITY_WORD = 3;
    const RETURN_DATA_COPY = 3;
    const FAST_STEP = 5;
    const BLAKE2_PER_ROUND = 1;
    const COLD_SLOAD = 2100;
    const COLD_ACCOUNT_ACCESS = 2600;
    const WARM_ACCESS = 100;
    const INIT_CODE_WORD_COST = 2;
    const MEMORY_COST_U128 = 0x200000000000000000000000000018000000000000000000000000000000;

    // @notice Compute the cost of the memory for a given words length.
    // @dev To avoid range_check overflow, we compute words_len / 512
    //      instead of words_len * words_len / 512. Then we recompute the
    //      resulting quotient: x^2 = 512q + r becomes
    //      x = 512 q0 + r0 => x^2 = 512(512 q0^2 + 2 q0 r0) + r0^2
    //      r0^2 = 512 q1 + r1
    //      x^2 = 512(512 q0^2 + 2 * q0 r0 + q1) + r1
    //      q = 512 * q0 * q0 + 2 q0 * r0 + q1
    // @param words_len The given number of words (bytes32).
    // @return cost The associated gas cost.
    func memory_cost{range_check_ptr}(words_len: felt) -> felt {
        let (q0, r0) = unsigned_div_rem(words_len, 512);
        let (q1, r1) = unsigned_div_rem(r0 * r0, 512);

        let memory_cost = 512 * q0 * q0 + 2 * q0 * r0 + q1 + (MEMORY * words_len);
        return memory_cost;
    }

    // @notice Compute the expansion cost of max_offset for the the memory
    // @param words_len The current length of the memory.
    // @param max_offset The target max_offset to be applied to the given memory.
    // @return cost The current expansion gas cost. 0 if no expansion is triggered.
    func calculate_gas_extend_memory{range_check_ptr}(words_len: felt, max_offset: felt) -> felt {
        alloc_locals;
        let memory_expansion = is_le(words_len * 32 - 1, max_offset);
        if (memory_expansion == FALSE) {
            return 0;
        }

        let prev_cost = memory_cost(words_len);
        let (new_words_len, _) = unsigned_div_rem(max_offset + 31, 32);
        let new_cost = memory_cost(new_words_len);

        return new_cost - prev_cost;
    }

    // @notive A saturated version of the memory_expansion_cost function
    // @dev Saturation at offset + size = 2^128.
    // @param words_len The current length of the memory as Uint256.
    // @param offset An offset to be applied to the given memory as Uint256.
    // @param size The size of the memory chunk.
    // @return cost The current expansion gas cost.
    func memory_expansion_cost_saturated{range_check_ptr}(
        words_len: felt, offset: Uint256, size: Uint256
    ) -> felt {
        if (offset.high + size.high != 0) {
            // Hardcoded value of cost(2^128)
            return MEMORY_COST_U128;
        }

        return calculate_gas_extend_memory(words_len, offset.low + size.low);
    }

    // @notice Given two memory chunks, compute the maximum expansion cost
    //  based on the maximum offset reached by each chunks.
    // @dev Memory expansion cost is computed over the `low` parts of
    // the offsets and sizes.  In the second step, we check whether the `high`
    // parts are non-zero and if so, we add the cost of expanding the memory by
    // 2**128 words (saturating).
    // @param words_len The current length of the memory as felt252.
    // @param offset_1 The offset of the first memory chunk as Uint256.
    // @param size_1 The size of the first memory chunk as Uint256.
    // @param offset_2 The offset of the second memory chunk as Uint256.
    // @param size_2 The size of the second memory chunk as Uint256.
    // @return cost The expansion gas cost for chunk who's ending offset is the largest.
    func max_memory_expansion_cost{range_check_ptr}(
        words_len: felt, offset_1: Uint256*, size_1: Uint256*, offset_2: Uint256*, size_2: Uint256*
    ) -> felt {
        alloc_locals;
        let max_expansion_is_2 = is_le(offset_1.low + size_1.low, offset_2.low + size_2.low);
        let max_expansion = max_expansion_is_2 * (offset_2.low + size_2.low) + (
            1 - max_expansion_is_2
        ) * (offset_1.low + size_1.low);

        let memory_expansion_cost = calculate_gas_extend_memory(words_len, max_expansion);
        let memory_expansion_cost = memory_expansion_cost + (
            offset_1.high + size_1.high + offset_2.high + size_2.high
        ) * Gas.MEMORY_COST_U128;

        return memory_expansion_cost;
    }

    // @notice Computes the base gas of a message call.
    // @dev This should be called after having withdrawn the gas relative to the
    // memory expansion and eventual extra gas costs.
    // @param gas_param The gas parameter of the message call, from the Stack.
    // @param gas_left The gas left in the current execution frame.
    // @return gas The base gas of the message call.
    func compute_message_call_gas{range_check_ptr}(gas_param: Uint256, gas_left: felt) -> felt {
        alloc_locals;
        let (quotient, _) = unsigned_div_rem(gas_left, 64);
        tempvar max_allowed_gas = gas_left - quotient;
        let (max_allowed_high, max_allowed_low) = split_felt(max_allowed_gas);
        tempvar max_allowed = Uint256(max_allowed_high, max_allowed_low);
        let (is_gas_param_lower) = uint256_lt(gas_param, max_allowed);

        // The message gas is the minimum between the gas param and the remaining gas left.
        if (is_gas_param_lower != FALSE) {
            // If gas is lower, it means that it fits in a felt and this is safe
            tempvar gas = gas_param.low + 2 ** 128 * gas_param.high;
            return gas;
        }
        return max_allowed.low;
    }
}
