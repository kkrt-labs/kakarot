use core::sha256::compute_sha256_u32_array;
use core::starknet::EthAddress;
use crate::errors::EVMError;
use crate::precompiles::Precompile;
use utils::math::Bitshift;
use utils::traits::bytes::{FromBytes, ToBytes};

const BASE_COST: u64 = 60;
const COST_PER_WORD: u64 = 12;

pub impl Sha256 of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x2.try_into().unwrap()
    }

    fn exec(mut input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        let mut sha256_input: Array<u32> = array![];
        while let Option::Some(bytes4) = input.multi_pop_front::<4>() {
            let bytes4 = (*bytes4).unbox();
            sha256_input.append(FromBytes::from_be_bytes(bytes4.span()).unwrap());
        };
        let (last_input_word, last_input_num_bytes) = if input.len() == 0 {
            (0, 0)
        } else {
            let mut last_input_word: u32 = 0;
            let mut last_input_num_bytes: u32 = 0;
            for remaining_byte in input {
                last_input_word = last_input_word.shl(8) + (*remaining_byte).into();
                last_input_num_bytes += 1;
            };
            (last_input_word, last_input_num_bytes)
        };
        let result_words_32: [u32; 8] = compute_sha256_u32_array(
            sha256_input, last_input_word, last_input_num_bytes
        );
        let mut result_bytes = array![];
        for word in result_words_32
            .span() {
                let word_bytes = (*word).to_be_bytes_padded();
                result_bytes.append_span(word_bytes);
            };

        return Result::Ok((gas, result_bytes.span()));
    }
}

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use crate::instructions::SystemOperationsTrait;

    use crate::memory::MemoryTrait;
    use crate::precompiles::sha256::Sha256;
    use crate::stack::StackTrait;
    use crate::test_utils::{
        VMBuilderTrait, MemoryTestUtilsTrait, native_token, setup_test_environment
    };
    use snforge_std::{start_mock_call};
    use utils::traits::bytes::{ToBytes, FromBytes};

    //source:
    //<https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcallZSizeZ_1XSizeb1FX_2jaddressY4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Y1j//%20v%5Cnq%20thVj%20wb~0x_Offset~Zb20jretYvPUSHXjargsWt%20Ve%20%01VWXYZ_bjqvw~_>
    #[test]
    fn test_sha_256_precompile() {
        let calldata = array![0xFF,];

        let (gas, result) = Sha256::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;

        assert_eq!(result, expected_result);
        assert_eq!(gas, 72);
    }

    #[test]
    fn test_sha_256_precompile_full_word() {
        let calldata = ToBytes::to_be_bytes(
            0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89_u256
        );

        let (gas, result) = Sha256::exec(calldata).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        let expected_result = 0xc0b057f584795eff8b06d5e420e71d747587d20de836f501921fd1b5741f1283;

        assert_eq!(result, expected_result);
        assert_eq!(gas, 72);
    }

    #[test]
    fn test_sha256_more_than_32_bytes() {
        let calldata = [
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0xf3,
            0x45,
            0x78,
            0x90,
            0x7f,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00
        ];

        let (gas, result) = Sha256::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        let expected_result = 0x3b745a1c00d035c334f358d007a430e4cf0ae63aa0556fb05529706de546464d;

        assert_eq!(result, expected_result);
        assert_eq!(gas, 84); // BASE + 2 WORDS
    }


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcallZSizeZ_1XSizeb1FX_2jaddressY4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Y1j//%20v%5Cnq%20thVj%20wb~0x_Offset~Zb20jretYvPUSHXjargsWt%20Ve%20%01VWXYZ_bjqvw~_>
    #[test]
    fn test_sha_256_precompile_static_call() {
        setup_test_environment();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x20).unwrap(); // retOffset
        vm.stack.push(0x1).unwrap(); // argsSize
        vm.stack.push(0x1F).unwrap(); // argsOffset
        vm.stack.push(0x2).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.memory.store_with_expansion(0xFF, 0x0);

        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x20);
        let expected_result = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89;
        assert_eq!(result, expected_result);
    }
}
