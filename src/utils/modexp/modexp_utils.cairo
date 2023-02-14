from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_mul_div_mod,
    uint256_mul,
    uint256_eq,
    uint256_lt,
    uint256_sub,
    uint256_unsigned_div_rem,
)
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bool import FALSE

// @title ModExpHelperMVP Functions
// @notice This file contains a selection of helper functions for modular exponentiation and gas cost calculation.
// @author @dragan2234
// @custom:namespace ModExpHelpers
namespace ModExpHelpers {
    // / @title Modular exponentiation calculation
    // / @author dragan2234
    // / @dev Computes x ** y % p for Uint256 numbers via fast modular exponentiation algorithm.
    // / Time complexity is log_2(y).
    // / Loop is implemented via uint256_mod_exp_recursive_call() function.
    func uint256_mod_exp{range_check_ptr: felt}(x: Uint256, y: Uint256, p: Uint256) -> (
        remainder: Uint256
    ) {
        alloc_locals;
        let res = Uint256(low=1, high=0);
        let (r_x, r_y, r_res) = uint256_mod_exp_recursive_call(x, y, res, p);
        let (quotient, remainder) = uint256_unsigned_div_rem(r_res, p);
        return (remainder=remainder);
    }

    func uint256_mod_exp_recursive_call{range_check_ptr: felt}(
        x: Uint256, y: Uint256, res: Uint256, p: Uint256
    ) -> (r_x: Uint256, r_y: Uint256, r_res: Uint256) {
        alloc_locals;
        let (is_greater_than_zero) = uint256_lt(Uint256(low=0, high=0), y);
        if (is_greater_than_zero == FALSE) {
            return (r_x=x, r_y=y, r_res=res);
        }

        let (quotient, remainder) = uint256_unsigned_div_rem(y, Uint256(low=2, high=0));
        let (is_equal_to_one) = uint256_eq(remainder, Uint256(low=1, high=0));
        if ((is_equal_to_one) == 0) {
            let (x_res_quotient, x_res_quotient_high, x_res_remainder) = uint256_mul_div_mod(
                x, x, p
            );
            return uint256_mod_exp_recursive_call(x=x_res_remainder, y=quotient, res=res, p=p);
        } else {
            let (
                x_res_res_quotient, x_res_res_quotient_high, x_res_res_remainder
            ) = uint256_mul_div_mod(res, x, p);
            let (x_res_quotient, x_res_quotient_high, x_res_remainder) = uint256_mul_div_mod(
                x, x, p
            );
            return uint256_mod_exp_recursive_call(
                x=x_res_remainder, y=quotient, res=x_res_res_remainder, p=p
            );
        }
    }
}
