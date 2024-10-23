use core::circuit::CircuitElement as CE;
use core::circuit::CircuitInput as CI;
use core::circuit::{
    u96, u384, circuit_add, circuit_sub, circuit_mul, EvalCircuitTrait, CircuitOutputsTrait,
    CircuitModulus, CircuitInputs, AddInputResultTrait
};
use core::cmp::{min, max};
use core::num::traits::Bounded;
use core::num::traits::OverflowingAdd;
use core::num::traits::Zero;
use core::starknet::EthAddress;

use crate::errors::EVMError;
use crate::precompiles::Precompile;

use utils::traits::bytes::{U8SpanExTrait, FromBytes, ToBytes};
use utils::traits::integer::BitsUsed;

const HEADER_LENGTH: usize = 96;
const MIN_GAS: u64 = 200;

pub impl ModExp of Precompile {
    fn address() -> EthAddress {
        0x5.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        // The format of input is:
        // <length_of_BASE> <length_of_EXPONENT> <length_of_MODULUS> <BASE> <EXPONENT> <MODULUS>
        // Where every length is a 32-byte left-padded integer representing the number of bytes
        // to be taken up by the next value

        // safe unwraps, since we will always get a 32 byte span
        let base_len: u256 = input.slice_right_padded(0, 32).from_be_bytes().unwrap();
        let exp_len: u256 = input.slice_right_padded(32, 32).from_be_bytes().unwrap();
        let mod_len: u256 = input.slice_right_padded(64, 32).from_be_bytes().unwrap();

        // cast base_len, exp_len , modulus_len to usize, it does not make sense to handle larger
        // values
        let base_len: usize = match base_len.try_into() {
            Option::Some(base_len) => { base_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('base_len casting to u32 failed'));
            }
        };
        let exp_len: usize = match exp_len.try_into() {
            Option::Some(exp_len) => { exp_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('exp_len casting to u32 failed'));
            }
        };
        let mod_len: usize = match mod_len.try_into() {
            Option::Some(mod_len) => { mod_len },
            Option::None => {
                return Result::Err(EVMError::InvalidParameter('mod_len casting to u32 failed'));
            }
        };

        // Handle a special case when both the base and mod length is zero
        if base_len == 0 && mod_len == 0 {
            return Result::Ok((MIN_GAS, [].span()));
        }

        // Used to extract ADJUSTED_EXPONENT_LENGTH.
        let exp_highp_len = min(exp_len, 32);

        let input = if input.len() >= HEADER_LENGTH {
            input.slice(HEADER_LENGTH, input.len() - HEADER_LENGTH)
        } else {
            [].span()
        };

        let exp_highp = {
            // get right padded bytes so if data.len is less then exp_len we will get right padded
            // zeroes.
            let right_padded_highp = input.slice_right_padded(base_len, 32);
            // If exp_len is less then 32 bytes get only exp_len bytes and do left padding.
            let out = right_padded_highp.slice(0, exp_highp_len).pad_left_with_zeroes(32);
            match out.from_be_bytes() {
                Option::Some(result) => result,
                Option::None => {
                    return Result::Err(EVMError::InvalidParameter('failed to extract exp_highp'));
                }
            }
        };

        let gas = calc_gas(base_len.into(), exp_len.into(), mod_len.into(), exp_highp);

        // Padding is needed if the input does not contain all 3 values.
        let (mod_start_idx, _) = base_len.overflowing_add(exp_len);
        let base = input.slice_right_padded(0, base_len).pad_left_with_zeroes(48);
        let exponent = input.slice_right_padded(base_len, exp_len).pad_left_with_zeroes(48);
        let modulus = input.slice_right_padded(mod_start_idx, mod_len).pad_left_with_zeroes(48);

        let base: u384 = base.try_into().unwrap();
        let exponent: u384 = exponent.try_into().unwrap();
        let modulus: u384 = modulus.try_into().unwrap();

        let output = modexp_circuit(base, exponent, modulus);
        let limb0_128: u128 = Into::<_, felt252>::into(output.limb0).try_into().unwrap();
        let limb1_128: u128 = Into::<_, felt252>::into(output.limb1).try_into().unwrap();
        let limb2_128: u128 = Into::<_, felt252>::into(output.limb2).try_into().unwrap();
        let limb3_128: u128 = Into::<_, felt252>::into(output.limb3).try_into().unwrap();

        let mut result_bytes = array![];
        if mod_len > 12 * 3 {
            result_bytes
                .append_span(limb3_128.to_be_bytes().pad_left_with_zeroes(mod_len - 12 * 3));
            result_bytes.append_span(limb2_128.to_be_bytes().pad_left_with_zeroes(12));
            result_bytes.append_span(limb1_128.to_be_bytes().pad_left_with_zeroes(12));
            result_bytes.append_span(limb0_128.to_be_bytes().pad_left_with_zeroes(12));
        } else if mod_len > 12 * 2 {
            result_bytes
                .append_span(limb2_128.to_be_bytes().pad_left_with_zeroes(mod_len - 12 * 2));
            result_bytes.append_span(limb1_128.to_be_bytes().pad_left_with_zeroes(12));
            result_bytes.append_span(limb0_128.to_be_bytes().pad_left_with_zeroes(12));
        } else if mod_len > 12 * 1 {
            result_bytes
                .append_span(limb1_128.to_be_bytes().pad_left_with_zeroes(mod_len - 12 * 1));
            result_bytes.append_span(limb0_128.to_be_bytes().pad_left_with_zeroes(12));
        } else {
            result_bytes.append_span(limb0_128.to_be_bytes().pad_left_with_zeroes(mod_len));
        }

        Result::Ok((gas.into(), result_bytes.span()))
    }
}

impl U8SpanTryIntoU384 of TryInto<Span<u8>, u384> {
    fn try_into(self: Span<u8>) -> Option<u384> {
        if self.len() != 48 {
            return Option::None;
        }
        let limb3_128: u128 = self.slice(0, 12).pad_left_with_zeroes(16).from_be_bytes().unwrap();
        let limb2_128: u128 = self.slice(12, 12).pad_left_with_zeroes(16).from_be_bytes().unwrap();
        let limb1_128: u128 = self.slice(24, 12).pad_left_with_zeroes(16).from_be_bytes().unwrap();
        let limb0_128: u128 = self.slice(36, 12).pad_left_with_zeroes(16).from_be_bytes().unwrap();
        let limb0: u96 = Into::<_, felt252>::into(limb0_128).try_into().unwrap();
        let limb1: u96 = Into::<_, felt252>::into(limb1_128).try_into().unwrap();
        let limb2: u96 = Into::<_, felt252>::into(limb2_128).try_into().unwrap();
        let limb3: u96 = Into::<_, felt252>::into(limb3_128).try_into().unwrap();
        Option::Some(u384 { limb0, limb1, limb2, limb3 })
    }
}

fn mod_exp_loop_inner(n: u384, bit: u384, base: u384, res: u384) -> (u384, u384) {
    let (_one, _base, _bit, _res) = (
        CE::<CI<0>> {}, CE::<CI<1>> {}, CE::<CI<2>> {}, CE::<CI<3>> {}
    );

    // Circuit
    // base_if_bit_else_one = (1 - bit)*(one) + bit*base
    // new_res = res * base_if_bit_else_one
    // new_base = base * base
    let base_if_bit_else_one = circuit_add(
        circuit_mul(circuit_sub(_one, _bit), _one), circuit_mul(_bit, _base)
    );
    let new_res = circuit_mul(base_if_bit_else_one, _res);
    let new_base = circuit_mul(_base, _base);

    let modulus = TryInto::<_, CircuitModulus>::try_into([n.limb0, n.limb1, n.limb2, n.limb3])
        .unwrap();

    let mut circuit_inputs = (new_res, new_base,).new_inputs();
    // Fill inputs:
    circuit_inputs = circuit_inputs.next([1, 0, 0, 0]);
    circuit_inputs = circuit_inputs.next(base);
    circuit_inputs = circuit_inputs.next(bit);
    circuit_inputs = circuit_inputs.next(res);

    let outputs = circuit_inputs.done().eval(modulus).unwrap();
    (outputs.get_output(new_res), outputs.get_output(new_base))
}

/// Computes the modular exponentiation x^y mod n up to 384 bits.
/// The algorithm uses the binary expansion of the exponent from right to left,
/// and use iterated squaring-and-multiply implemented using a circuit.
/// Resource: <https://en.wikipedia.org/wiki/Modular_exponentiation#Right-to-left-binary-method>
///
/// # Arguments
///
/// * `x` a `u384` value representing the base.
/// * `y` a `u384` value representing the exponent.
/// * `n` a `u384` value representing the modulus.
///
/// # Returns
///
/// * `u384` - The result of the modular exponentiation x^y mod n.
pub fn modexp_circuit(x: u384, y: u384, n: u384) -> u384 {
    if n.is_zero() {
        return 0.into();
    }
    if n == 1.into() {
        return 0.into();
    }
    if y.is_zero() {
        return 1.into();
    }
    if x.is_zero() {
        return 0.into();
    }

    let bits = get_u384_bits_little(y);
    let mut res = 1.into();
    let mut base = x;
    for bit in bits {
        let (_res, _base) = mod_exp_loop_inner(n, bit.into(), base, res);
        res = _res;
        base = _base;
    };

    res
}


// Returns the bits of the 384 bit integer in little endian format.
fn get_u384_bits_little(s: u384) -> Array<felt252> {
    let mut bits = array![];
    let mut s_limb0: u128 = Into::<_, felt252>::into(s.limb0).try_into().unwrap();
    while s_limb0 != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_limb0, 2);
        bits.append(r.into());
        s_limb0 = q;
    };
    let mut s_limb1: u128 = Into::<_, felt252>::into(s.limb1).try_into().unwrap();
    if s_limb1 != 0 {
        while bits.len() != 96 {
            bits.append(0);
        }
    }
    while s_limb1 != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_limb1, 2);
        bits.append(r.into());
        s_limb1 = q;
    };
    let mut s_limb2: u128 = Into::<_, felt252>::into(s.limb2).try_into().unwrap();
    if s_limb2 != 0 {
        while bits.len() != 192 {
            bits.append(0);
        }
    }
    while s_limb2 != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_limb2, 2);
        bits.append(r.into());
        s_limb2 = q;
    };
    let mut s_limb3: u128 = Into::<_, felt252>::into(s.limb3).try_into().unwrap();
    if s_limb3 != 0 {
        while bits.len() != 288 {
            bits.append(0);
        }
    }
    while s_limb3 != 0 {
        let (q, r) = core::traits::DivRem::div_rem(s_limb3, 2);
        bits.append(r.into());
        s_limb3 = q;
    };
    bits
}

// Calculate gas cost according to EIP 2565:
// https://eips.ethereum.org/EIPS/eip-2565
fn calc_gas(base_length: u64, exp_length: u64, mod_length: u64, exp_highp: u256) -> u64 {
    let multiplication_complexity = calculate_multiplication_complexity(base_length, mod_length);

    let iteration_count = calculate_iteration_count(exp_length, exp_highp);

    let gas = (multiplication_complexity * iteration_count.into()) / 3;
    let gas: u64 = gas.try_into().unwrap_or(Bounded::<u64>::MAX);

    max(gas, 200)
}

fn calculate_multiplication_complexity(base_length: u64, mod_length: u64) -> u256 {
    let max_length = max(base_length, mod_length);

    let _8: NonZero<u64> = 8_u64.try_into().unwrap();
    let (words, rem) = DivRem::div_rem(max_length, _8);

    let words: u256 = if rem != 0 {
        (words + 1).into()
    } else {
        words.into()
    };

    words * words
}

fn calculate_iteration_count(exp_length: u64, exp_highp: u256) -> u64 {
    let mut iteration_count: u64 = if exp_length < 33 {
        if exp_highp == 0 {
            0
        } else {
            (exp_highp.bits_used() - 1).into()
        }
    } else {
        let length_part = 8 * (exp_length - 32);
        let bits_part = if exp_highp != 0 {
            exp_highp.bits_used() - 1
        } else {
            0
        };

        length_part + bits_part.into()
    };

    max(iteration_count, 1)
}

#[cfg(test)]
mod tests {
    use core::circuit::{u96, u384};
    use core::result::ResultTrait;
    use core::starknet::EthAddress;

    use crate::precompiles::modexp::ModExp;
    use crate::test_data::test_data_modexp::{
        test_modexp_modsize0_returndatasizeFiller_data,
        test_modexp_create2callPrecompiles_test0_berlin_data, test_modexp_eip198_example_1_data,
        test_modexp_eip198_example_2_data, test_modexp_nagydani_1_square_data,
        test_modexp_nagydani_1_qube_data
    };

    use super::modexp_circuit;

    use utils::traits::bytes::{U8SpanExTrait, FromBytes, ToBytes};

    const TWO_31: u256 = 2147483648;
    const PREV_PRIME_384: u384 =
        u384 {
            limb0: 0xfffffffffffffffffffffec3,
            limb1: 0xffffffffffffffffffffffff,
            limb2: 0xffffffffffffffffffffffff,
            limb3: 0xffffffffffffffffffffffff
        };
    const PREV_PRIME_384_M1: u384 =
        u384 {
            limb0: 0xfffffffffffffffffffffec2,
            limb1: 0xffffffffffffffffffffffff,
            limb2: 0xffffffffffffffffffffffff,
            limb3: 0xffffffffffffffffffffffff
        };
    const PREV_PRIME_384_M2: u384 =
        u384 {
            limb0: 0xfffffffffffffffffffffec1,
            limb1: 0xffffffffffffffffffffffff,
            limb2: 0xffffffffffffffffffffffff,
            limb3: 0xffffffffffffffffffffffff
        };

    #[test]
    fn test_modexp_circuit() {
        let TWO_31_M1: u384 = 2147483647.into();
        let TWO_31_M2: u384 = 2147483646.into();
        assert_eq!(modexp_circuit(2.into(), TWO_31_M2, TWO_31_M1), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(3.into(), TWO_31_M2, TWO_31_M1), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(5.into(), TWO_31_M2, TWO_31_M1), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(7.into(), TWO_31_M2, TWO_31_M1), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(11.into(), TWO_31_M2, TWO_31_M1), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(2.into(), TWO_31_M2, TWO_31_M1.into()), 1.into(), "wrong result");
        assert_eq!(modexp_circuit(2.into(), 5.into(), 30.into()), 2.into(), "wrong result");
        assert_eq!(
            modexp_circuit(
                123456789.into(), 987654321.into(), 11111111111111111111111111111111.into()
            ),
            6929919895158922141640454333396.into(),
            "wrong result"
        );
    }

    #[test]
    fn test_modexp_circuit_worst_case() {
        assert_eq!(
            modexp_circuit(PREV_PRIME_384_M2, PREV_PRIME_384_M1, PREV_PRIME_384),
            1.into(),
            "wrong result"
        );
    }

    #[test]
    fn test_edge_case_circuit() {
        assert_eq!(mod_exp_circuit(12.into(), 42.into(), 0.into()), 0.into(), "wrong result");
        assert_eq!(mod_exp_circuit(12.into(), 42.into(), 1.into()), 0.into(), "wrong result");
        assert_eq!(mod_exp_circuit(0.into(), 42.into(), 42.into()), 0.into(), "wrong result");
        assert_eq!(mod_exp_circuit(42.into(), 0.into(), 42.into()), 1.into(), "wrong result");
        assert_eq!(mod_exp_circuit(0.into(), 0.into(), 42.into()), 1.into(), "wrong result");
    }


    #[test]
    fn test_modexp_precompile_input_output_worst() {
        let mut calldata = array![];
        let l0f: u128 = Into::<_, felt252>::into(PREV_PRIME_384_M2.limb0).try_into().unwrap();
        let l1f: u128 = Into::<_, felt252>::into(PREV_PRIME_384_M2.limb1).try_into().unwrap();
        let size = array![48_u8].span().pad_left_with_zeroes(32);
        calldata.append_span(size);
        calldata.append_span(size);
        calldata.append_span(size);

        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l0f.to_be_bytes());

        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span((l0f + 1).to_be_bytes());

        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span(l1f.to_be_bytes());
        calldata.append_span((l0f + 2).to_be_bytes());

        let (gas, result) = ModExp::exec(calldata.span()).unwrap();
        let expected_result = array![1].span().pad_left_with_zeroes(48);
        let expected_gas = 4596;
        assert_eq!(result, expected_result);
        assert_eq!(gas, expected_gas);
    }

    #[test]
    fn test_modexp_precompile_input_output_all_sizes() {
        #[cairofmt::skip]
        let prime_deltas = array![7_u16, 3, 43, 15, 15, 21, 81, 13, 15, 13, 7, 61, 111, 25, 451, 
        51, 85, 175, 253, 7, 87, 427, 27, 133, 235, 375, 423, 735, 357, 115, 81, 297, 175,
         57, 45, 127, 61, 37, 91, 27, 15, 241, 231, 55, 105, 127, 115];

        let mut size = 2_u32;
        for delta in prime_deltas {
            let mut modulus: Array<u8> = array![];
            modulus.append(1);
            for _i in 2..size - 1 {
                modulus.append(0);
            };
            if size > 2 {
                modulus.append((delta.into() / 256_u16).try_into().unwrap());
            }
            modulus.append((delta % 256).try_into().unwrap());

            let mut base: Array<u8> = Default::default();
            let delta_base = delta - 2;
            base.append(1);
            for _i in 2..size - 1 {
                base.append(0);
            };
            if size > 2 {
                base.append((delta_base.into() / 256_u16).try_into().unwrap());
            }
            base.append((delta_base % 256).try_into().unwrap());

            let delta_exponent = delta - 1;
            let mut exponent: Array<u8> = Default::default();
            exponent.append(1);
            for _i in 2..size - 1 {
                exponent.append(0);
            };
            if size > 2 {
                exponent.append((delta_exponent.into() / 256_u16).try_into().unwrap());
            }
            exponent.append((delta_exponent % 256).try_into().unwrap());

            let size_bytes = size.to_be_bytes().pad_left_with_zeroes(32);
            let mut calldata = array![];
            calldata.append_span(size_bytes);
            calldata.append_span(size_bytes);
            calldata.append_span(size_bytes);
            calldata.append_span(base.span());
            calldata.append_span(exponent.span());
            calldata.append_span(modulus.span());

            let (gas, result) = ModExp::exec(calldata.span()).unwrap();
            let expected_result_bytes = 1_u8.to_be_bytes();

            assert_eq!(result, expected_result_bytes.pad_left_with_zeroes(size));

            size = size + 1;
        }
    }

    //#[test]
    fn test_modexp_modsize0_returndatasizeFiller_filler() {
        let (calldata, expected) = test_modexp_modsize0_returndatasizeFiller_data();
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, 44_954);
    }

    //#[test]
    fn test_modexp_create2callPrecompiles_test0_berlin() {
        let (calldata, expected) = test_modexp_create2callPrecompiles_test0_berlin_data();
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, 1_360);
    }

    #[test]
    fn test_modexp_eip198_example_1() {
        let (calldata, expected) = test_modexp_eip198_example_1_data();
        let expected_gas = 1_360;
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, expected_gas);
    }

    #[test]
    fn test_modexp_eip198_example_2() {
        let (calldata, expected) = test_modexp_eip198_example_2_data();
        let expected_gas = 1_360;
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, expected_gas);
    }


    //#[test]
    fn test_modexp_nagydani_1_square() {
        let (calldata, expected) = test_modexp_nagydani_1_square_data();
        let expected_gas = 200;
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, expected_gas);
    }

    //#[test]
    fn test_modexp_nagydani_1_qube() {
        let (calldata, expected) = test_modexp_nagydani_1_qube_data();
        let expected_gas = 200;
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, expected_gas);
    }

    #[test]
    fn test_modexp_berlin_empty_input() {
        let calldata = [].span();
        let expected = [].span();
        let expected_gas = 200;
        let (gas, result) = ModExp::exec(calldata).unwrap();
        assert_eq!(result, expected);
        assert_eq!(gas, expected_gas);
    }
}
