pub(crate) mod ec_add;
pub(crate) mod ec_mul;
use core::circuit::CircuitElement as CE;
use core::circuit::CircuitInput as CI;
use core::circuit::{
    u96, u384, CircuitElement, CircuitInput, circuit_add, circuit_sub, circuit_mul, circuit_inverse,
    EvalCircuitTrait, CircuitOutputsTrait, CircuitModulus, CircuitInputs
};
use core::num::traits::Zero;
use garaga::core::circuit::AddInputResultTrait2;

const BN254_ORDER: u256 = 0x30644E72E131A029B85045B68181585D2833E84879B9709143E1F593F0000001;
const BN254_PRIME: u256 = 0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47;
const BN254_PRIME_LIMBS: [
    u96
    ; 4] = [
    0x6871ca8d3c208c16d87cfd47, 0xb85045b68181585d97816a91, 0x30644e72e131a029, 0x0
];

// Check if a point is on the curve.
// Point at infinity (0,0) will return false.
pub fn is_on_curve(x: u384, y: u384) -> bool {
    let (b, _x, _y) = (CE::<CI<0>> {}, CE::<CI<1>> {}, CE::<CI<2>> {});

    // Compute (y^2 - (x^3 + b)) % p_bn254
    let x2 = circuit_mul(_x, _x);
    let x3 = circuit_mul(x2, _x);
    let y2 = circuit_mul(_y, _y);
    let rhs = circuit_add(x3, b);
    let check = circuit_sub(y2, rhs);

    let modulus = TryInto::<_, CircuitModulus>::try_into(BN254_PRIME_LIMBS)
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (check,).new_inputs();
    // Prefill constants:
    circuit_inputs = circuit_inputs.next_2([3, 0, 0, 0]);
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(x);
    circuit_inputs = circuit_inputs.next_2(y);

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();
    let zero_check: u384 = outputs.get_output(check);
    return zero_check.is_zero();
}


// Double BN254 EC point without checking if the point is on the curve
pub fn double_ec_point_unchecked(x: u384, y: u384) -> (u384, u384) {
    // CONSTANT stack
    let in0 = CE::<CI<0>> {}; // 0x3
    // INPUT stack
    let (_x, _y) = (CE::<CI<1>> {}, CE::<CI<2>> {});

    let x2 = circuit_mul(_x, _x);
    let num = circuit_mul(in0, x2);
    let den = circuit_add(_y, _y);
    let inv_den = circuit_inverse(den);
    let slope = circuit_mul(num, inv_den);
    let slope_sqr = circuit_mul(slope, slope);

    let nx = circuit_sub(circuit_sub(slope_sqr, _x), _x);
    let ny = circuit_sub(circuit_mul(slope, circuit_sub(_x, nx)), _y);

    let modulus = TryInto::<_, CircuitModulus>::try_into(BN254_PRIME_LIMBS)
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (nx, ny,).new_inputs();
    // Prefill constants:
    circuit_inputs = circuit_inputs.next_2([0x3, 0x0, 0x0, 0x0]); // in0
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(x); // in1
    circuit_inputs = circuit_inputs.next_2(y); // in2

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();

    (outputs.get_output(nx), outputs.get_output(ny))
}


// returns true if a == b mod p_bn254
pub fn eq_mod_p(a: u384, b: u384) -> bool {
    let in1 = CircuitElement::<CircuitInput<0>> {};
    let in2 = CircuitElement::<CircuitInput<1>> {};
    let sub = circuit_sub(in1, in2);

    let modulus = TryInto::<_, CircuitModulus>::try_into(BN254_PRIME_LIMBS)
        .unwrap(); // BN254 prime field modulus

    let outputs = (sub,).new_inputs().next_2(a).next_2(b).done_2().eval(modulus).unwrap();

    return outputs.get_output(sub).is_zero();
}

// returns true if a == -b mod p_bn254
pub fn eq_neg_mod_p(a: u384, b: u384) -> bool {
    let _a = CE::<CI<0>> {};
    let _b = CE::<CI<1>> {};
    let check = circuit_add(_a, _b);

    let modulus = TryInto::<_, CircuitModulus>::try_into(BN254_PRIME_LIMBS)
        .unwrap(); // BN254 prime field modulus

    let outputs = (check,).new_inputs().next_2(a).next_2(b).done_2().eval(modulus).unwrap();

    return outputs.get_output(check).is_zero();
}
