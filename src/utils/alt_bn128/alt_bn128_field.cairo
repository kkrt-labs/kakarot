// SPDX-License-Identifier: MIT

%lang starknet

// Library copied from https://github.com/tekkac/cairo-alt_bn128

// Starkware dependencies
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

// Internal dependencies
from utils.alt_bn128.bigint import (
    BASE,
    BigInt3,
    UnreducedBigInt3,
    UnreducedBigInt5,
    nondet_bigint3,
    bigint_mul,
)
from utils.alt_bn128.alt_bn128_def import P0, P1, P2

// FIELD STRUCTURES
struct FQ2 {
    e0: BigInt3,
    e1: BigInt3,
}

struct FQ12 {
    e0: BigInt3,
    e1: BigInt3,
    e2: BigInt3,
    e3: BigInt3,
    e4: BigInt3,
    e5: BigInt3,
    e6: BigInt3,
    e7: BigInt3,
    e8: BigInt3,
    e9: BigInt3,
    eA: BigInt3,
    eB: BigInt3,
}

struct unreducedFQ12 {
    e0: UnreducedBigInt5,
    e1: UnreducedBigInt5,
    e2: UnreducedBigInt5,
    e3: UnreducedBigInt5,
    e4: UnreducedBigInt5,
    e5: UnreducedBigInt5,
    e6: UnreducedBigInt5,
    e7: UnreducedBigInt5,
    e8: UnreducedBigInt5,
    e9: UnreducedBigInt5,
    eA: UnreducedBigInt5,
    eB: UnreducedBigInt5,
}

// FIELD CONSTANTS
func fq_zero() -> (res: BigInt3) {
    return (BigInt3(0, 0, 0),);
}

func fq2_zero() -> (res: FQ2) {
    return (FQ2(
        e0=BigInt3(0, 0, 0),
        e1=BigInt3(0, 0, 0),
        ),);
}

func fq12_zero() -> (res: FQ12) {
    return (
        FQ12(
        e0=BigInt3(0, 0, 0), e1=BigInt3(0, 0, 0), e2=BigInt3(0, 0, 0),
        e3=BigInt3(0, 0, 0), e4=BigInt3(0, 0, 0), e5=BigInt3(0, 0, 0),
        e6=BigInt3(0, 0, 0), e7=BigInt3(0, 0, 0), e8=BigInt3(0, 0, 0),
        e9=BigInt3(0, 0, 0), eA=BigInt3(0, 0, 0), eB=BigInt3(0, 0, 0),
        ),
    );
}

func fq12_one() -> (res: FQ12) {
    return (
        FQ12(
        e0=BigInt3(1, 0, 0), e1=BigInt3(0, 0, 0), e2=BigInt3(0, 0, 0),
        e3=BigInt3(0, 0, 0), e4=BigInt3(0, 0, 0), e5=BigInt3(0, 0, 0),
        e6=BigInt3(0, 0, 0), e7=BigInt3(0, 0, 0), e8=BigInt3(0, 0, 0),
        e9=BigInt3(0, 0, 0), eA=BigInt3(0, 0, 0), eB=BigInt3(0, 0, 0),
        ),
    );
}

func verify_zero3{range_check_ptr}(val: BigInt3) {
    alloc_locals;
    local flag;
    local q;
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import pack
        from starkware.cairo.common.math_utils import as_int

        P = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47

        v = pack(ids.val, PRIME) 
        q, r = divmod(v, P)
        assert r == 0, f"verify_zero: Invalid input {ids.val.d0, ids.val.d1, ids.val.d2}."

        ids.flag = 1 if q > 0 else 0
        q = q if q > 0 else 0-q
        ids.q = q % PRIME
    %}
    assert [range_check_ptr] = q + 2 ** 127;

    tempvar carry1 = ((2 * flag - 1) * q * P0 - val.d0) / BASE;
    assert [range_check_ptr + 1] = carry1 + 2 ** 127;

    tempvar carry2 = ((2 * flag - 1) * q * P1 - val.d1 + carry1) / BASE;
    assert [range_check_ptr + 2] = carry2 + 2 ** 127;

    assert (2 * flag - 1) * q * P2 - val.d2 + carry2 = 0;

    let range_check_ptr = range_check_ptr + 3;

    return ();
}

func verify_zero5{range_check_ptr}(val: UnreducedBigInt5) {
    alloc_locals;
    local flag;
    local q1;
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import pack
        from starkware.cairo.common.math_utils import as_int

        P = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47

        v3 = as_int(ids.val.d3, PRIME)
        v4 = as_int(ids.val.d4, PRIME)
        v = pack(ids.val, PRIME) + v3*2**258 + v4*2**344

        q, r = divmod(v, P)
        assert r == 0, f"verify_zero: Invalid input {ids.val.d0, ids.val.d1, ids.val.d2, ids.val.d3, ids.val.d4}."

        # Since q usually doesn't fit BigInt3, divide it again
        ids.flag = 1 if q > 0 else 0
        q = q if q > 0 else 0-q
        q1, q2 = divmod(q, P)
        ids.q1 = q1
        value = k = q2
    %}
    let (k) = nondet_bigint3();
    let fullk = BigInt3(q1 * P0 + k.d0, q1 * P1 + k.d1, q1 * P2 + k.d2);
    let P = BigInt3(P0, P1, P2);
    let (k_n) = bigint_mul(fullk, P);

    // val mod n = 0, so val = k_n
    tempvar carry1 = ((2 * flag - 1) * k_n.d0 - val.d0) / BASE;
    assert [range_check_ptr + 0] = carry1 + 2 ** 127;

    tempvar carry2 = ((2 * flag - 1) * k_n.d1 - val.d1 + carry1) / BASE;
    assert [range_check_ptr + 1] = carry2 + 2 ** 127;

    tempvar carry3 = ((2 * flag - 1) * k_n.d2 - val.d2 + carry2) / BASE;
    assert [range_check_ptr + 2] = carry3 + 2 ** 127;

    tempvar carry4 = ((2 * flag - 1) * k_n.d3 - val.d3 + carry3) / BASE;
    assert [range_check_ptr + 3] = carry4 + 2 ** 127;

    assert (2 * flag - 1) * k_n.d4 - val.d4 + carry4 = 0;

    let range_check_ptr = range_check_ptr + 4;

    return ();
}

// returns 1 if x ==0 mod alt_bn128 prime
func is_zero{range_check_ptr}(x: BigInt3) -> (res: felt) {
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import pack
        P = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47
        x = pack(ids.x, PRIME) % P
    %}
    if (nondet %{ x == 0 %} != 0) {
        verify_zero3(x);
        // verify_zero5(UnreducedBigInt5(d0=x.d0, d1=x.d1, d2=x.d2, d3=0, d4=0))
        return (res=1);
    }

    %{
        from starkware.python.math_utils import div_mod
        value = x_inv = div_mod(1, x, P)
    %}
    let (x_inv) = nondet_bigint3();
    let (x_x_inv) = bigint_mul(x, x_inv);

    // Check that x * x_inv = 1 to verify that x != 0.
    verify_zero5(
        UnreducedBigInt5(
        d0=x_x_inv.d0 - 1,
        d1=x_x_inv.d1,
        d2=x_x_inv.d2,
        d3=x_x_inv.d3,
        d4=x_x_inv.d4),
    );
    return (res=0);
}

// FQ12 verify

func verify_zero_fq12{range_check_ptr}(x: FQ12) {
    verify_zero3(x.e0);
    verify_zero3(x.e1);
    verify_zero3(x.e2);
    verify_zero3(x.e3);
    verify_zero3(x.e4);
    verify_zero3(x.e5);
    verify_zero3(x.e6);
    verify_zero3(x.e7);
    verify_zero3(x.e8);
    verify_zero3(x.e9);
    verify_zero3(x.eA);
    verify_zero3(x.eB);
    return ();
}

func fq_eq_zero(x: BigInt3) -> (res: felt) {
    if (x.d0 != 0) {
        return (res=0);
    }
    if (x.d1 != 0) {
        return (res=0);
    }
    if (x.d2 != 0) {
        return (res=0);
    }
    return (res=1);
}

func fq12_eq_zero(x: FQ12) -> (res: felt) {
    let (e0_is_zero) = fq_eq_zero(x.e0);
    if (e0_is_zero == 0) {
        return (res=0);
    }
    let (e1_is_zero) = fq_eq_zero(x.e1);
    if (e1_is_zero == 0) {
        return (res=0);
    }
    let (e2_is_zero) = fq_eq_zero(x.e2);
    if (e2_is_zero == 0) {
        return (res=0);
    }
    let (e3_is_zero) = fq_eq_zero(x.e3);
    if (e3_is_zero == 0) {
        return (res=0);
    }
    let (e4_is_zero) = fq_eq_zero(x.e4);
    if (e4_is_zero == 0) {
        return (res=0);
    }
    let (e5_is_zero) = fq_eq_zero(x.e5);
    if (e5_is_zero == 0) {
        return (res=0);
    }
    let (e6_is_zero) = fq_eq_zero(x.e6);
    if (e6_is_zero == 0) {
        return (res=0);
    }
    let (e7_is_zero) = fq_eq_zero(x.e7);
    if (e7_is_zero == 0) {
        return (res=0);
    }
    let (e8_is_zero) = fq_eq_zero(x.e8);
    if (e8_is_zero == 0) {
        return (res=0);
    }
    let (e9_is_zero) = fq_eq_zero(x.e9);
    if (e9_is_zero == 0) {
        return (res=0);
    }
    let (eA_is_zero) = fq_eq_zero(x.eA);
    if (eA_is_zero == 0) {
        return (res=0);
    }
    let (eB_is_zero) = fq_eq_zero(x.eB);
    if (eB_is_zero == 0) {
        return (res=0);
    }
    return (res=1);
}

func fq12_is_zero{range_check_ptr}(x: FQ12) -> (res: felt) {
    %{
        import sys, os 
        cwd = os.getcwd()
        sys.path.append(cwd)

        from utils.bn128_field import FQ, FQ12
        from utils.bn128_utils import parse_fq12

        val = list(map(FQ, parse_fq12(ids.x)))

        if FQ12(val) == FQ12([0]*12):
            x = 0
        else: 
            x = 1
    %}
    if (nondet %{ x == 0 %} != 0) {
        verify_zero_fq12(x);
        return (res=1);
    }

    %{
        val = list(map(FQ, parse_fq12(ids.x)))
        val = FQ12(val).inv()
        value = list(map(lambda x: x.n, val.coeffs))
    %}
    let (x_inv) = nondet_fq12();

    // TODO VERIF x * x_inv - 1 = 0
    return (res=0);
}

// Difference of two FQ12, resulting FQ12 BigInt3 limbs can be negative
func fq12_diff(x: FQ12, y: FQ12) -> (res: FQ12) {
    return (
        res=FQ12(
        BigInt3(d0=x.e0.d0 - y.e0.d0, d1=x.e0.d1 - y.e0.d1, d2=x.e0.d2 - y.e0.d2),
        BigInt3(d0=x.e1.d0 - y.e1.d0, d1=x.e1.d1 - y.e1.d1, d2=x.e1.d2 - y.e1.d2),
        BigInt3(d0=x.e2.d0 - y.e2.d0, d1=x.e2.d1 - y.e2.d1, d2=x.e2.d2 - y.e2.d2),
        BigInt3(d0=x.e3.d0 - y.e3.d0, d1=x.e3.d1 - y.e3.d1, d2=x.e3.d2 - y.e3.d2),
        BigInt3(d0=x.e4.d0 - y.e4.d0, d1=x.e4.d1 - y.e4.d1, d2=x.e4.d2 - y.e4.d2),
        BigInt3(d0=x.e5.d0 - y.e5.d0, d1=x.e5.d1 - y.e5.d1, d2=x.e5.d2 - y.e5.d2),
        BigInt3(d0=x.e6.d0 - y.e6.d0, d1=x.e6.d1 - y.e6.d1, d2=x.e6.d2 - y.e6.d2),
        BigInt3(d0=x.e7.d0 - y.e7.d0, d1=x.e7.d1 - y.e7.d1, d2=x.e7.d2 - y.e7.d2),
        BigInt3(d0=x.e8.d0 - y.e8.d0, d1=x.e8.d1 - y.e8.d1, d2=x.e8.d2 - y.e8.d2),
        BigInt3(d0=x.e9.d0 - y.e9.d0, d1=x.e9.d1 - y.e9.d1, d2=x.e9.d2 - y.e9.d2),
        BigInt3(d0=x.eA.d0 - y.eA.d0, d1=x.eA.d1 - y.eA.d1, d2=x.eA.d2 - y.eA.d2),
        BigInt3(d0=x.eB.d0 - y.eB.d0, d1=x.eB.d1 - y.eB.d1, d2=x.eB.d2 - y.eB.d2)),
    );
}

func fq12_sum(x: FQ12, y: FQ12) -> (res: FQ12) {
    return (
        res=FQ12(
        BigInt3(d0=x.e0.d0 + y.e0.d0, d1=x.e0.d1 + y.e0.d1, d2=x.e0.d2 + y.e0.d2),
        BigInt3(d0=x.e1.d0 + y.e1.d0, d1=x.e1.d1 + y.e1.d1, d2=x.e1.d2 + y.e1.d2),
        BigInt3(d0=x.e2.d0 + y.e2.d0, d1=x.e2.d1 + y.e2.d1, d2=x.e2.d2 + y.e2.d2),
        BigInt3(d0=x.e3.d0 + y.e3.d0, d1=x.e3.d1 + y.e3.d1, d2=x.e3.d2 + y.e3.d2),
        BigInt3(d0=x.e4.d0 + y.e4.d0, d1=x.e4.d1 + y.e4.d1, d2=x.e4.d2 + y.e4.d2),
        BigInt3(d0=x.e5.d0 + y.e5.d0, d1=x.e5.d1 + y.e5.d1, d2=x.e5.d2 + y.e5.d2),
        BigInt3(d0=x.e6.d0 + y.e6.d0, d1=x.e6.d1 + y.e6.d1, d2=x.e6.d2 + y.e6.d2),
        BigInt3(d0=x.e7.d0 + y.e7.d0, d1=x.e7.d1 + y.e7.d1, d2=x.e7.d2 + y.e7.d2),
        BigInt3(d0=x.e8.d0 + y.e8.d0, d1=x.e8.d1 + y.e8.d1, d2=x.e8.d2 + y.e8.d2),
        BigInt3(d0=x.e9.d0 + y.e9.d0, d1=x.e9.d1 + y.e9.d1, d2=x.e9.d2 + y.e9.d2),
        BigInt3(d0=x.eA.d0 + y.eA.d0, d1=x.eA.d1 + y.eA.d1, d2=x.eA.d2 + y.eA.d2),
        BigInt3(d0=x.eB.d0 + y.eB.d0, d1=x.eB.d1 + y.eB.d1, d2=x.eB.d2 + y.eB.d2)),
    );
}

// TODO

// FIELD MULTIPLICATION

// func ufq12_mul{range_check_ptr}(a : FQ12, b : FQ12) -> (res : unreducedFQ12):
//     let ab_e0 = bigint_mul(a.e0, b.d0)
//     let ab_e0 = bigint_mul(a.e0, b.d0)
//     return (
//     unreducedFQ12(
//     e0=

// end

// TODO deterministic (unreduced FQ12?)
func fq12_mul{range_check_ptr}(a: FQ12, b: FQ12) -> (res: FQ12) {
    %{
        import sys, os
        cwd = os.getcwd()
        sys.path.append(cwd)
        from utils.bn128_field import FQ, FQ12
        from utils.bn128_utils import parse_fq12, print_g12
        a = FQ12(list(map(FQ, parse_fq12(ids.a))))
        b = FQ12(list(map(FQ, parse_fq12(ids.b))))
        value = res = list(map(lambda x: x.n, (a*b).coeffs))
        # print("a*b =", value)
    %}
    let (res) = nondet_fq12();
    // TODO CHECKS
    return (res=res);
}

func fq12_pow_inner{range_check_ptr}(x: FQ12, n: felt, m: felt) -> (pow2: FQ12, res: FQ12) {
    if (m == 0) {
        assert n = 0;
        let (one) = fq12_one();
        return (pow2=x, res=one);
    }

    alloc_locals;
    let (x_sqr) = fq12_mul(x, x);

    %{ memory[ap] = (ids.n % PRIME) % 2 %}
    jmp odd if [ap] != 0, ap++;
    return fq12_pow_inner(x=x_sqr, n=n / 2, m=m - 1);

    odd:
    let (inner_pow, inner_res) = fq12_pow_inner(x=x_sqr, n=(n - 1) / 2, m=m - 1);
    let (res) = fq12_mul(inner_res, x);
    return (inner_pow, res);
}

func fq12_pow_3{range_check_ptr}(x: FQ12, n: BigInt3) -> (pow2: FQ12, res: FQ12) {
    alloc_locals;
    let (pow2_0: FQ12, local res0: FQ12) = fq12_pow_inner(x, n.d0, 86);
    let (pow2_1: FQ12, local res1: FQ12) = fq12_pow_inner(pow2_0, n.d1, 86);
    let (pow2_2, local res2: FQ12) = fq12_pow_inner(pow2_1, n.d2, 86);
    let (res: FQ12) = fq12_mul(res0, res1);
    let (res: FQ12) = fq12_mul(res, res2);
    return (pow2_2, res);
}

func fq12_pow_12{range_check_ptr}(x: FQ12, n: FQ12) -> (res: FQ12) {
    alloc_locals;
    let (pow2_0: FQ12, local res0: FQ12) = fq12_pow_3(x, n.e0);
    let (pow2_1: FQ12, local res1: FQ12) = fq12_pow_3(pow2_0, n.e1);
    let (pow2_2: FQ12, local res2: FQ12) = fq12_pow_3(pow2_1, n.e2);
    let (pow2_3: FQ12, local res3: FQ12) = fq12_pow_3(pow2_2, n.e3);
    let (pow2_4: FQ12, local res4: FQ12) = fq12_pow_3(pow2_3, n.e4);
    let (pow2_5: FQ12, local res5: FQ12) = fq12_pow_3(pow2_4, n.e5);
    let (pow2_6: FQ12, local res6: FQ12) = fq12_pow_3(pow2_5, n.e6);
    let (pow2_7: FQ12, local res7: FQ12) = fq12_pow_3(pow2_6, n.e7);
    let (pow2_8: FQ12, local res8: FQ12) = fq12_pow_3(pow2_7, n.e8);
    let (pow2_9: FQ12, local res9: FQ12) = fq12_pow_3(pow2_8, n.e9);
    let (pow2_A: FQ12, local resA: FQ12) = fq12_pow_3(pow2_9, n.eA);
    // Simplifications since eB = 0
    // let (pow2_B : FQ12, local resB : FQ12) = fq12_pow_3(pow2_A, n.eB)
    let (local res01: FQ12) = fq12_mul(res0, res1);
    let (local res23: FQ12) = fq12_mul(res2, res3);
    let (local res45: FQ12) = fq12_mul(res4, res5);
    let (local res67: FQ12) = fq12_mul(res6, res7);
    let (local res89: FQ12) = fq12_mul(res8, res9);
    // let (local resAB : FQ12) = fq12_mul(resA, resB)
    let (local res0123: FQ12) = fq12_mul(res01, res23);
    let (local res4567: FQ12) = fq12_mul(res45, res67);
    // let (local res89AB : FQ12) = fq12_mul(res89, resAB)
    let (local res89A: FQ12) = fq12_mul(res89, resA);
    let (local res0123: FQ12) = fq12_mul(res01, res23);
    let (local res0__7: FQ12) = fq12_mul(res0123, res4567);
    let (res: FQ12) = fq12_mul(res0__7, res89A);
    return (res,);
}

// Hint argument: value
// a 12 element list of field elements
func nondet_fq12{range_check_ptr}() -> (res: FQ12) {
    let res: FQ12 = [cast(ap + 38, FQ12*)];
    %{
        from starkware.cairo.common.cairo_secp.secp_utils import split

        r = ids.res
        var_list = [r.e0, r.e1, r.e2, r.e3, r.e4, r.e5, 
                    r.e6, r.e7, r.e8, r.e9, r.eA, r.eB]
        #segments.write_arg(ids.res.e0.address_, split(val[0]))
        for (var, val) in zip(var_list, value):
            segments.write_arg(var.address_, split(val))
    %}
    const MAX_SUM = 12 * 3 * (2 ** 86 - 1);
    // TODO RANGE CHECKS? (WHY THE ASSERT LIKE THIS BTW?)
    assert [range_check_ptr] = MAX_SUM - (res.e0.d0 + res.e0.d1 + res.e0.d2 + res.e1.d0 + res.e1.d1 + res.e1.d2 +
        res.e2.d0 + res.e2.d1 + res.e2.d2 + res.e3.d0 + res.e3.d1 + res.e3.d2 +
        res.e4.d0 + res.e4.d1 + res.e4.d2 + res.e5.d0 + res.e5.d1 + res.e5.d2 +
        res.e6.d0 + res.e6.d1 + res.e6.d2 + res.e7.d0 + res.e7.d1 + res.e7.d2 +
        res.e8.d0 + res.e8.d1 + res.e8.d2 + res.e9.d0 + res.e9.d1 + res.e9.d2 +
        res.eA.d0 + res.eA.d1 + res.eA.d2 + res.eB.d0 + res.eB.d1 + res.eB.d2);

    tempvar range_check_ptr = range_check_ptr + 37;
    [range_check_ptr - 1] = res.e0.d0, ap++;
    [range_check_ptr - 2] = res.e0.d1, ap++;
    [range_check_ptr - 3] = res.e0.d2, ap++;
    [range_check_ptr - 4] = res.e1.d0, ap++;
    [range_check_ptr - 5] = res.e1.d1, ap++;
    [range_check_ptr - 6] = res.e1.d2, ap++;
    [range_check_ptr - 7] = res.e2.d0, ap++;
    [range_check_ptr - 8] = res.e2.d1, ap++;
    [range_check_ptr - 9] = res.e2.d2, ap++;
    [range_check_ptr - 10] = res.e3.d0, ap++;
    [range_check_ptr - 11] = res.e3.d1, ap++;
    [range_check_ptr - 12] = res.e3.d2, ap++;
    [range_check_ptr - 13] = res.e4.d0, ap++;
    [range_check_ptr - 14] = res.e4.d1, ap++;
    [range_check_ptr - 15] = res.e4.d2, ap++;
    [range_check_ptr - 16] = res.e5.d0, ap++;
    [range_check_ptr - 17] = res.e5.d1, ap++;
    [range_check_ptr - 18] = res.e5.d2, ap++;
    [range_check_ptr - 19] = res.e6.d0, ap++;
    [range_check_ptr - 20] = res.e6.d1, ap++;
    [range_check_ptr - 21] = res.e6.d2, ap++;
    [range_check_ptr - 22] = res.e7.d0, ap++;
    [range_check_ptr - 23] = res.e7.d1, ap++;
    [range_check_ptr - 24] = res.e7.d2, ap++;
    [range_check_ptr - 25] = res.e8.d0, ap++;
    [range_check_ptr - 26] = res.e8.d1, ap++;
    [range_check_ptr - 27] = res.e8.d2, ap++;
    [range_check_ptr - 28] = res.e9.d0, ap++;
    [range_check_ptr - 29] = res.e9.d1, ap++;
    [range_check_ptr - 30] = res.e9.d2, ap++;
    [range_check_ptr - 31] = res.eA.d0, ap++;
    [range_check_ptr - 32] = res.eA.d1, ap++;
    [range_check_ptr - 33] = res.eA.d2, ap++;
    [range_check_ptr - 34] = res.eB.d0, ap++;
    [range_check_ptr - 35] = res.eB.d1, ap++;
    [range_check_ptr - 36] = res.eB.d2, ap++;
    static_assert &res + FQ12.SIZE == ap;
    return (res=res);
}
