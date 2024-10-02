use core::circuit::u384;
use core::option::Option;
use core::starknet::{EthAddress};

use crate::errors::EVMError;
use crate::precompiles::Precompile;
use crate::precompiles::ec_operations::ec_add::ec_safe_add;
use crate::precompiles::ec_operations::{is_on_curve, double_ec_point_unchecked, BN254_PRIME};
use utils::traits::bytes::{ToBytes, U8SpanExTrait, FromBytes};

const BASE_COST: u64 = 6000;
const U256_BYTES_LEN: usize = 32;

pub impl EcMul of Precompile {
    fn address() -> EthAddress {
        0x7.try_into().unwrap()
    }

    fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = BASE_COST;

        // Pad the input to 128 bytes to avoid out-of-bounds accesses
        let mut input = input.pad_right_with_zeroes(96);

        let x1: u256 = input.slice(0, 32).from_be_bytes().unwrap();

        let y1: u256 = input.slice(32, 32).from_be_bytes().unwrap();

        let s: u256 = input.slice(64, 32).from_be_bytes().unwrap();

        let (x, y) = match ec_mul(x1, y1, s) {
            Option::Some((x, y)) => { (x, y) },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('invalid ec_mul parameters'));
            },
        };

        // Append x and y to the result bytes.
        let mut result_bytes = array![];
        let x_bytes = x.to_be_bytes_padded();
        result_bytes.append_span(x_bytes);
        let y_bytes = y.to_be_bytes_padded();
        result_bytes.append_span(y_bytes);

        return Result::Ok((gas, result_bytes.span()));
    }
}

// Returns Option::None in case of error.
fn ec_mul(x1: u256, y1: u256, s: u256) -> Option<(u256, u256)> {
    if x1 >= BN254_PRIME || y1 >= BN254_PRIME {
        return Option::None;
    }
    if x1 == 0 && y1 == 0 {
        // Input point is at infinity, return it
        return Option::Some((x1, y1));
    } else {
        // Point is not at infinity
        let x1_u384: u384 = x1.into();
        let y1_u384: u384 = y1.into();

        if is_on_curve(x1_u384, y1_u384) {
            if s == 0 {
                return Option::Some((0, 0));
            } else if s == 1 {
                return Option::Some((x1, y1));
            } else {
                // Point is on the curve.
                // s is >= 2.
                let bits = get_bits_little(s);
                let pt = ec_mul_inner((x1_u384, y1_u384), bits);
                match pt {
                    Option::Some((
                        x, y
                    )) => Option::Some((x.try_into().unwrap(), y.try_into().unwrap())),
                    Option::None => Option::Some((0, 0)),
                }
            }
        } else {
            // Point is not on the curve
            return Option::None;
        }
    }
}

// Returns the bits of the 256 bit number in little endian format.
fn get_bits_little(s: u256) -> Array<felt252> {
    let mut bits = ArrayTrait::new();
    let mut s_low = s.low;
    while s_low != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_low, 2);
        bits.append(r.into());
        s_low = q;
    };
    let mut s_high = s.high;
    if s_high != 0 {
        while bits.len() != 128 {
            bits.append(0);
        }
    }
    while s_high != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_high, 2);
        bits.append(r.into());
        s_high = q;
    };
    bits
}


// Should not be called outside of ec_mul.
// Returns Option::None in case of point at infinity.
// The size of bits array must be at minimum 2 and the point must be on the curve.
fn ec_mul_inner(pt: (u384, u384), mut bits: Array<felt252>) -> Option<(u384, u384)> {
    let (mut temp_x, mut temp_y) = pt;
    let mut result: Option<(u384, u384)> = Option::None;
    for bit in bits {
        if bit != 0 {
            match result {
                Option::Some((xr, yr)) => result = ec_safe_add(temp_x, temp_y, xr, yr),
                Option::None => result = Option::Some((temp_x, temp_y)),
            };
        };
        let (_temp_x, _temp_y) = double_ec_point_unchecked(temp_x, temp_y);
        temp_x = _temp_x;
        temp_y = _temp_y;
    };

    return result;
}

#[cfg(test)]
mod tests {
    use super::ec_mul;

    #[test]
    fn test_ec_mul() {
        let (x1, y1, s) = (1, 2, 2);
        let (x, y) = ec_mul(x1, y1, s).expect('ec_mul failed');
        assert_eq!(x, 0x030644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd3);
        assert_eq!(y, 0x15ed738c0e0a7c92e7845f96b2ae9c0a68a6a449e3538fc7ff3ebf7a5a18a2c4);
    }
}
