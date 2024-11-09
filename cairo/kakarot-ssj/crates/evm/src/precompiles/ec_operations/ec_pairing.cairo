use core::num::traits::Zero;
use core::starknet::{EthAddress};
use crate::errors::EVMError;
use crate::precompiles::Precompile;
use crate::precompiles::ec_operations::{is_on_curve, BN254_PRIME};
use garaga::circuits::tower_circuits::run_BN254_E12T_MUL_circuit;
use garaga::definitions::G1G2Pair;
use garaga::ec_ops_g2::{G2PointTrait, ec_mul as ec_mul_g2};

use garaga::single_pairing_tower::{
    E12TOne, G1Point, G2Point, miller_loop_bn254_tower, final_exp_bn254_tower, u384
};
use utils::constants::{ONE_32_BYTES, ZERO_32_BYTES};
use utils::traits::bytes::FromBytes;

const BASE_COST: u64 = 45000;
const PAIRING_COST: u64 = 34000;
const U256_BYTES_LEN: usize = 32;
const GARAGA_BN254_CURVE_INDEX: u32 = 0;
const BN254_CURVE_ORDER: u256 =
    21888242871839275222246405745257275088548364400416034343698204186575808495617;

pub impl EcPairing of Precompile {
    fn address() -> EthAddress {
        0x8.try_into().unwrap()
    }

    fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let (n, rem) = DivRem::div_rem(input.len(), 192);

        let gas = PAIRING_COST * n.into() + BASE_COST;

        if rem != 0 {
            // rem != 0: input length must be a multiple of 196
            return Result::Err(EVMError::InvalidParameter('invalid ec_pairing input length'));
        }
        if n == 0 {
            return Result::Ok((BASE_COST, ONE_32_BYTES.span()));
        }

        let mut pairs: Array<G1G2Pair> = array![];
        let mut offset = 0;
        let mut everything_ok = true;
        for _ in 0_usize
            ..n {
                let x: u256 = input.slice(offset, U256_BYTES_LEN).from_be_bytes().unwrap();
                let y: u256 = input.slice(offset + 32, U256_BYTES_LEN).from_be_bytes().unwrap();
                let x1: u256 = input.slice(offset + 64, U256_BYTES_LEN).from_be_bytes().unwrap();
                let x0: u256 = input.slice(offset + 96, U256_BYTES_LEN).from_be_bytes().unwrap();
                let y1: u256 = input.slice(offset + 128, U256_BYTES_LEN).from_be_bytes().unwrap();
                let y0: u256 = input.slice(offset + 160, U256_BYTES_LEN).from_be_bytes().unwrap();

                if x >= BN254_PRIME
                    || y >= BN254_PRIME
                    || x0 >= BN254_PRIME
                    || x1 >= BN254_PRIME
                    || y0 >= BN254_PRIME
                    || y1 >= BN254_PRIME {
                    everything_ok = false;
                    break;
                }

                // If p and q are not the point at infinity, check that it's they're on the curve.
                let x_384: u384 = x.into();
                let y_384: u384 = y.into();
                let p = G1Point { x: x_384, y: y_384 };
                let p_infinity = p.is_zero();
                if (!p_infinity) {
                    if (!is_on_curve(x_384, y_384)) {
                        everything_ok = false;
                        break;
                    }
                }

                let q = G2Point { x0: x0.into(), x1: x1.into(), y0: y0.into(), y1: y1.into() };
                let q_infinity = q.is_zero();
                if (!q_infinity) {
                    if (!q.is_on_curve(GARAGA_BN254_CURVE_INDEX)) {
                        everything_ok = false;
                        break;
                    }
                }

                // Subgroup check
                // Cofactor for G1 group is 1, so we don't need to check for `p`
                let q_mul_r = ec_mul_g2(q, BN254_CURVE_ORDER, GARAGA_BN254_CURVE_INDEX).unwrap();
                if (!q_mul_r.is_zero()) {
                    everything_ok = false;
                    break;
                }

                pairs.append(G1G2Pair { p: p, q: q });
                offset += 192;
            };

        if !everything_ok {
            return Result::Err(EVMError::InvalidParameter('invalid ec_pairing input'));
        }

        let res = ec_pairing(pairs.span());

        let result_bytes = match res {
            true => { ONE_32_BYTES.span() },
            false => { ZERO_32_BYTES.span() },
        };

        return Result::Ok((gas, result_bytes));
    }
}

// Assumes len is >= 1.
// Assumes pairs are on curve.
// Returns true if Π e(Pi,Qi) = 1 where e is the optimal ate pairing on BN254
fn ec_pairing(mut pairs: Span<G1G2Pair>) -> bool {
    let n_pairs = pairs.len();
    let pair_0 = pairs.pop_front().unwrap();
    let (mut m,) = match pair_0.p.is_zero() || pair_0.q.is_zero() {
        true => {
            if n_pairs == 1 {
                return true;
            }
            (E12TOne::one(),)
        },
        false => { miller_loop_bn254_tower(*pair_0.p, *pair_0.q) }
    };

    // The original input had only one pair
    if n_pairs == 1 {
        return final_exp_bn254_tower(m).is_one();
    };

    for pair_i in pairs {
        let (__m,) = match pair_i.p.is_zero() || pair_i.q.is_zero() {
            true => { (E12TOne::one(),) },
            false => { miller_loop_bn254_tower(*pair_i.p, *pair_i.q) }
        };
        let (_m) = run_BN254_E12T_MUL_circuit(m, __m);
        m = _m;
    };

    let f = final_exp_bn254_tower(m);
    return f.is_one();
}
#[cfg(test)]
mod tests {
    use super::EcPairing;
    use utils::constants::ONE_32_BYTES;

    #[test]
    fn test_ec_pairing() {
        #[cairofmt::skip]
        let bytes_input: Array<u8> = array![
            0x2c, 0xf4, 0x44, 0x99, 0xd5, 0xd2, 0x7b, 0xb1, 0x86, 0x30, 0x8b, 0x7a, 0xf7, 0xaf, 0x2, 0xac, 0x5b, 0xc9, 0xee, 0xb6, 0xa3, 0xd1, 0x47, 0xc1, 0x86, 0xb2, 0x1f, 0xb1, 0xb7, 0x6e, 0x18, 0xda, 0x2c,
            0xf, 0x0, 0x1f, 0x52, 0x11, 0xc, 0xcf, 0xe6, 0x91, 0x8, 0x92, 0x49, 0x26, 0xe4, 0x5f, 0xb, 0xc, 0x86, 0x8d, 0xf0, 0xe7, 0xbd, 0xe1, 0xfe, 0x16, 0xd3, 0x24, 0x2d, 0xc7, 0x15, 0xf6, 0x1f, 0xb1,
            0x9b, 0xb4, 0x76, 0xf6, 0xb9, 0xe4, 0x4e, 0x2a, 0x32, 0x23, 0x4d, 0xa8, 0x21, 0x2f, 0x61, 0xcd, 0x63, 0x91, 0x93, 0x54, 0xbc, 0x6, 0xae, 0xf3, 0x1e, 0x3c, 0xfa, 0xff, 0x3e, 0xbc, 0x22, 0x60, 0x68,
            0x45, 0xff, 0x18, 0x67, 0x93, 0x91, 0x4e, 0x3, 0xe2, 0x1d, 0xf5, 0x44, 0xc3, 0x4f, 0xfe, 0x2f, 0x2f, 0x35, 0x4, 0xde, 0x8a, 0x79, 0xd9, 0x15, 0x9e, 0xca, 0x2d, 0x98, 0xd9, 0x2b, 0xd3, 0x68, 0xe2, 0x83, 0x81, 0xe8, 0xec, 0xcb, 0x5f, 0xa8, 0x1f, 0xc2, 0x6c,
            0xf3, 0xf0, 0x48, 0xee, 0xa9, 0xab, 0xfd, 0xd8, 0x5d, 0x7e, 0xd3, 0xab, 0x36, 0x98, 0xd6, 0x3e, 0x4f, 0x90, 0x2f, 0xe0, 0x2e, 0x47, 0x88, 0x75, 0x7, 0xad, 0xf0, 0xff, 0x17, 0x43, 0xcb, 0xac, 0x6b,
            0xa2, 0x91, 0xe6, 0x6f, 0x59, 0xbe, 0x6b, 0xd7, 0x63, 0x95, 0xb, 0xb1, 0x60, 0x41, 0xa0, 0xa8, 0x5e, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1, 0x30, 0x64, 0x4e, 0x72, 0xe1, 0x31, 0xa0, 0x29, 0xb8, 0x50, 0x45, 0xb6, 0x81, 0x81, 0x58, 0x5d, 0x97,
            0x81, 0x6a, 0x91, 0x68, 0x71, 0xca, 0x8d, 0x3c, 0x20, 0x8c, 0x16, 0xd8, 0x7c, 0xfd, 0x45, 0x19, 0x71, 0xff, 0x4, 0x71, 0xb0, 0x9f, 0xa9, 0x3c, 0xaa, 0xf1, 0x3c, 0xbf, 0x44, 0x3c, 0x1a, 0xed, 0xe0,
            0x9c, 0xc4, 0x32, 0x8f, 0x5a, 0x62, 0xaa, 0xd4, 0x5f, 0x40, 0xec, 0x13, 0x3e, 0xb4, 0x9, 0x10, 0x58, 0xa3, 0x14, 0x18, 0x22, 0x98, 0x57, 0x33, 0xcb, 0xdd, 0xdf, 0xed, 0xf, 0xd8, 0xd6, 0xc1, 0x4,
            0xe9, 0xe9, 0xef, 0xf4, 0xb, 0xf5, 0xab, 0xfe, 0xf9, 0xab, 0x16, 0x3b, 0xc7, 0x2a, 0x23, 0xaf, 0x9a, 0x5c, 0xe2, 0xba, 0x27, 0x96, 0xc1, 0xf4, 0xe4, 0x53, 0xa3, 0x70, 0xeb, 0xa, 0xf8, 0xc2, 0x12,
            0xd9, 0xdc, 0x9a, 0xcd, 0x8f, 0xc0, 0x2c, 0x2e, 0x90, 0x7b, 0xae, 0xa2, 0x23, 0xa8, 0xeb, 0xb, 0x9, 0x96, 0x25, 0x2c, 0xb5, 0x48, 0xa4, 0x48, 0x7d, 0xa9, 0x7b, 0x2, 0x42, 0x2e, 0xbc, 0xe,
            0x83, 0x46, 0x13, 0xf9, 0x54, 0xde, 0x6c, 0x7e, 0xa, 0xfd, 0xc1, 0xfc
        ];

        let result = EcPairing::exec(bytes_input.span());
        let (_gas, return_data) = result.unwrap();
        assert_eq!(return_data, ONE_32_BYTES.span());
    }
}
