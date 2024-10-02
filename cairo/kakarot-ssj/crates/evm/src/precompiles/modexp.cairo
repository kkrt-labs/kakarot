use core::cmp::{min, max};

use core::num::traits::Bounded;
use core::num::traits::OverflowingAdd;
// CREDITS: The implementation has take reference from
// [revm](https://github.com/bluealloy/revm/blob/main/crates/precompile/src/modexp.rs)

use core::option::OptionTrait;
use core::starknet::EthAddress;
use core::traits::TryInto;

use crate::errors::EVMError;

use crate::precompiles::Precompile;
use utils::crypto::modexp::lib::modexp;
use utils::traits::bytes::{U8SpanExTrait, FromBytes};
use utils::traits::integer::BitsUsed;

const HEADER_LENGTH: usize = 96;
const MIN_GAS: u64 = 200;

pub impl ModExp of Precompile {
    #[inline(always)]
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
        let base = input.slice_right_padded(0, base_len);
        let exponent = input.slice_right_padded(base_len, exp_len);

        let (mod_start_idx, _) = base_len.overflowing_add(exp_len);

        let modulus = input.slice_right_padded(mod_start_idx, mod_len);

        let output = modexp(base, exponent, modulus);

        let return_data = output.pad_left_with_zeroes(mod_len);
        Result::Ok((gas.into(), return_data))
    }
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

#[cfg(tests)]
mod tests {
    use core::result::ResultTrait;
    use core::starknet::EthAddress;
    use core::starknet::testing::set_contract_address;

    use crate::instructions::SystemOperationsTrait;

    use crate::memory::MemoryTrait;
    use crate::precompiles::Precompiles;
    use crate::stack::StackTrait;
    use crate::test_utils::{VMBuilderTrait, native_token, other_starknet_address};
    use evm_tests::test_precompiles::test_data::test_data_modexp::{
        test_modexp_modsize0_returndatasizeFiller_data,
        test_modexp_create2callPrecompiles_test0_berlin_data, test_modexp_eip198_example_1_data,
        test_modexp_eip198_example_2_data, test_modexp_nagydani_1_square_data,
        test_modexp_nagydani_1_qube_data
    };
    use snforge_std::{start_mock_call, test_address};
    use utils::helpers::U256Trait;

    // the tests are taken from
    // [revm](https://github.com/bluealloy/revm/blob/0629883f5a40e913a5d9498fa37886348c858c70/crates/precompile/src/modexp.rs#L175)

    #[test]
    fn test_modexp_modsize0_returndatasizeFiller_filler() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_modsize0_returndatasizeFiller_data();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;

        let expected_gas = 44_954;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }

    #[test]
    fn test_modexp_create2callPrecompiles_test0_berlin() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_create2callPrecompiles_test0_berlin_data();

        vm.message.data = calldata;
        vm.message.target.evm = EthAddress { address: 5 };
        let expected_gas = 1_360;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }

    #[test]
    fn test_modexp_eip198_example_1() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_eip198_example_1_data();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;
        let expected_gas = 1_360;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }

    #[test]
    fn test_modexp_eip198_example_2() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_eip198_example_2_data();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;
        let expected_gas = 1_360;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }


    #[test]
    fn test_modexp_nagydani_1_square() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_nagydani_1_square_data();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;
        let expected_gas = 200;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }

    #[test]
    fn test_modexp_nagydani_1_qube() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let (calldata, expected) = test_modexp_nagydani_1_qube_data();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;
        let expected_gas = 200;

        let gas_before = vm.gas_left;
        Precompiles::exec_precompile(ref vm).unwrap();
        let gas_after = vm.gas_left;

        assert_eq!(gas_before - gas_after, expected_gas);
        assert_eq!(vm.return_data, expected);
    }

    #[test]
    fn test_modexp_berlin_empty_input() {
        let mut vm = VMBuilderTrait::new_with_presets().build();

        let calldata = [].span();
        let expected = [].span();

        vm.message.target.evm = EthAddress { address: 5 };
        vm.message.data = calldata;

        Precompiles::exec_precompile(ref vm).unwrap();

        assert_eq!(vm.return_data, expected);
    }
}
