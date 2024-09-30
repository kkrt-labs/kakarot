use core::circuit::CircuitElement as CE;
use core::circuit::CircuitInput as CI;

use core::circuit::{
    u384, circuit_sub, circuit_mul, circuit_inverse, EvalCircuitTrait, CircuitOutputsTrait,
    CircuitModulus, CircuitInputs
};
use core::option::Option;
use core::starknet::{EthAddress};
use crate::errors::EVMError;
use crate::precompiles::Precompile;
use crate::precompiles::ec_operations::{
    eq_mod_p, eq_neg_mod_p, is_on_curve, double_ec_point_unchecked, BN254_PRIME_LIMBS, BN254_PRIME
};
use garaga::core::circuit::AddInputResultTrait2;
use utils::traits::bytes::{ToBytes, U8SpanExTrait, FromBytes};


const BASE_COST: u64 = 150;
const U256_BYTES_LEN: usize = 32;
pub impl EcAdd of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x6.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = BASE_COST;

        // Pad the input to 128 bytes to avoid out-of-bounds accesses
        let mut input = input.pad_right_with_zeroes(128);

        let x1: u256 = input.slice(0, 32).from_be_bytes().unwrap();

        let y1: u256 = input.slice(32, 32).from_be_bytes().unwrap();

        let x2: u256 = input.slice(64, 32).from_be_bytes().unwrap();

        let y2: u256 = input.slice(96, 32).from_be_bytes().unwrap();

        let (x, y) = match ec_add(x1, y1, x2, y2) {
            Option::Some((x, y)) => { (x, y) },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('invalid ec_add parameters'));
            },
        };

        let mut result_bytes = array![];
        // Append x to the result bytes.
        let x_bytes = x.to_be_bytes_padded();
        result_bytes.append_span(x_bytes);
        // Append y to the result bytes.
        let y_bytes = y.to_be_bytes_padded();
        result_bytes.append_span(y_bytes);

        return Result::Ok((gas, result_bytes.span()));
    }
}


fn ec_add(x1: u256, y1: u256, x2: u256, y2: u256) -> Option<(u256, u256)> {
    if x1 >= BN254_PRIME || y1 >= BN254_PRIME || x2 >= BN254_PRIME || y2 >= BN254_PRIME {
        return Option::None;
    }
    if x1 == 0 && y1 == 0 {
        if x2 == 0 && y2 == 0 {
            // Both are points at infinity, return either of them.
            return Option::Some((x2, y2));
        } else {
            // Only first point is at infinity.
            let x2_u384: u384 = x2.into();
            let y2_u384: u384 = y2.into();
            if is_on_curve(x2_u384, y2_u384) {
                // Second point is on the curve, return it.
                return Option::Some((x2, y2));
            } else {
                // Second point is not on the curve, return None (error).
                return Option::None;
            }
        }
    } else if x2 == 0 && y2 == 0 {
        // Only second point is at infinity.
        let x1_u384: u384 = x1.into();
        let y1_u384: u384 = y1.into();
        if is_on_curve(x1_u384, y1_u384) {
            // First point is on the curve, return it.
            return Option::Some((x1, y1));
        } else {
            // First point is not on the curve, return None (error).
            return Option::None;
        }
    } else {
        // None of the points are at infinity.
        let x1_u384: u384 = x1.into();
        let x2_u384: u384 = x2.into();
        let y1_u384: u384 = y1.into();
        let y2_u384: u384 = y2.into();

        if is_on_curve(x1_u384, y1_u384) && is_on_curve(x2_u384, y2_u384) {
            match ec_safe_add(x1_u384, y1_u384, x2_u384, y2_u384) {
                Option::Some((
                    x, y
                )) => Option::Some(
                    (
                        TryInto::<u384, u256>::try_into(x).unwrap(),
                        TryInto::<u384, u256>::try_into(y).unwrap()
                    )
                ),
                Option::None => Option::Some((0, 0)),
            }
        } else {
            // None of the points are infinity and at least one of them is not on the curve.
            return Option::None;
        }
    }
}


// assumes that the points are on the curve and not the point at infinity.
// Returns None if the points are the same and opposite y coordinates (Point at infinity)
pub fn ec_safe_add(x1: u384, y1: u384, x2: u384, y2: u384) -> Option<(u384, u384)> {
    let same_x = eq_mod_p(x1, x2);

    if same_x {
        let opposite_y = eq_neg_mod_p(y1, y2);

        if opposite_y {
            return Option::None;
        } else {
            let (x, y) = double_ec_point_unchecked(x1, y1);
            return Option::Some((x, y));
        }
    } else {
        let (x, y) = add_ec_point_unchecked(x1, y1, x2, y2);
        return Option::Some((x, y));
    }
}

// Add two BN254 EC points without checking if:
// - the points are on the curve
// - the points are not the same
// - none of the points are the point at infinity
fn add_ec_point_unchecked(xP: u384, yP: u384, xQ: u384, yQ: u384) -> (u384, u384) {
    // INPUT stack
    let (_xP, _yP, _xQ, _yQ) = (CE::<CI<0>> {}, CE::<CI<1>> {}, CE::<CI<2>> {}, CE::<CI<3>> {});

    let num = circuit_sub(_yP, _yQ);
    let den = circuit_sub(_xP, _xQ);
    let inv_den = circuit_inverse(den);
    let slope = circuit_mul(num, inv_den);
    let slope_sqr = circuit_mul(slope, slope);

    let nx = circuit_sub(circuit_sub(slope_sqr, _xP), _xQ);
    let ny = circuit_sub(circuit_mul(slope, circuit_sub(_xP, nx)), _yP);

    let modulus = TryInto::<_, CircuitModulus>::try_into(BN254_PRIME_LIMBS)
        .unwrap(); // BN254 prime field modulus

    let mut circuit_inputs = (nx, ny,).new_inputs();
    // Fill inputs:
    circuit_inputs = circuit_inputs.next_2(xP); // in1
    circuit_inputs = circuit_inputs.next_2(yP); // in2
    circuit_inputs = circuit_inputs.next_2(xQ); // in3
    circuit_inputs = circuit_inputs.next_2(yQ); // in4

    let outputs = circuit_inputs.done_2().eval(modulus).unwrap();

    (outputs.get_output(nx), outputs.get_output(ny))
}


#[cfg(test)]
mod tests {
    use super::ec_add;
    #[test]
    fn test_ec_add() {
        let x1 = 1;
        let y1 = 2;
        let x2 = 1;
        let y2 = 2;
        let (x, y) = ec_add(x1, y1, x2, y2).expect('ec_add failed');
        assert_eq!(x, 0x030644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd3);
        assert_eq!(y, 0x15ed738c0e0a7c92e7845f96b2ae9c0a68a6a449e3538fc7ff3ebf7a5a18a2c4);
    }
}
