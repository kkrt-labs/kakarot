// SPDX-License-Identifier: MIT

%lang starknet

// Library copied from https://github.com/tekkac/cairo-alt_bn128

// Starkware dependencies
from starkware.cairo.common.cairo_secp.bigint import UnreducedBigInt3, BigInt3

// The base of the representation.
const BASE = 2 ** 86;

// Represents a big integer: sum_i(BASE**i * d_i).
// Note that the limbs (d_i) are NOT restricted to the range [0, BASE) and in particular they
// can be negative.
struct UnreducedBigInt5 {
    d0: felt,
    d1: felt,
    d2: felt,
    d3: felt,
    d4: felt,
}

func bigint_mul(x: BigInt3, y: BigInt3) -> (res: UnreducedBigInt5) {
    return (
        UnreducedBigInt5(
            d0=x.d0 * y.d0,
            d1=x.d0 * y.d1 + x.d1 * y.d0,
            d2=x.d0 * y.d2 + x.d1 * y.d1 + x.d2 * y.d0,
            d3=x.d1 * y.d2 + x.d2 * y.d1,
            d4=x.d2 * y.d2,
        ),
    );
}

// Returns a BigInt3 instance whose value is controlled by a prover hint.
//
// Soundness guarantee: each limb is in the range [0, 3 * BASE).
// Completeness guarantee (honest prover): the value is in reduced form and in particular,
// each limb is in the range [0, BASE).
//
// Hint arguments: value.
func nondet_bigint3{range_check_ptr}() -> (res: BigInt3) {
    // The result should be at the end of the stack after the function returns.
    let res: BigInt3 = [cast(ap + 5, BigInt3*)];
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import split
        segments.write_arg(ids.res.address_, split(value))
    %}
    // The maximal possible sum of the limbs, assuming each of them is in the range [0, BASE).
    const MAX_SUM = 3 * (BASE - 1);
    assert [range_check_ptr] = MAX_SUM - (res.d0 + res.d1 + res.d2);

    // Prepare the result at the end of the stack.
    tempvar range_check_ptr = range_check_ptr + 4;
    [range_check_ptr - 3] = res.d0, ap++;
    [range_check_ptr - 2] = res.d1, ap++;
    [range_check_ptr - 1] = res.d2, ap++;
    static_assert &res + BigInt3.SIZE == ap;
    return (res=res);
}
