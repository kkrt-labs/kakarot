// @title MathHelpers utils
// @notice This file contains utils for cairo common math functions
// @custom:namespace MathHelpers
namespace MathHelpers {
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
        from starkware.cairo.common.math import assert_le
        assert_le(r, div - 1);

        assert value = q * div + r;
        return (q, r);
    }

    // @dev This is code from to cairo.common.math.unsigned_dev_rem.
    // @dev of div == 2**128 as well.
    // @param value: 128bit value to divide.
    // @param div: divisor.
    //  0 <= q < rc_bound, 0 <= r < div and value = q * div + r.
    // Assumption: 0 < div <= PRIME / rc_bound.
    // Prover assumption: value / div < rc_bound.
    // The value of div is restricted to make sure there is no overflow.
    // q * div + r < (q + 1) * div <= rc_bound * (PRIME / rc_bound) = PRIME.
    // @return: quotient and remainder.
    func unsigned_div_rem{range_check_ptr}(value, div) -> (q: felt, r: felt) {
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
        from starkware.cairo.common.math import assert_le
        assert_le(r, div - 1);

        assert value = q * div + r;
        return (q, r);
    }
}
