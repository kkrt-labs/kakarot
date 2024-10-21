use core::starknet::EthAddress;
use crate::errors::EVMError;
use crate::precompiles::Precompile;
use utils::helpers::bytes_32_words_size;

const BASE_COST: u64 = 15;
const COST_PER_WORD: u64 = 3;

pub impl Identity of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x4.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let data_word_size = bytes_32_words_size(input.len());
        let gas = BASE_COST + data_word_size.into() * COST_PER_WORD;

        return Result::Ok((gas, input));
    }
}

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use crate::instructions::SystemOperationsTrait;

    use crate::memory::MemoryTrait;
    use crate::precompiles::identity::Identity;
    use crate::stack::StackTrait;
    use crate::test_utils::{
        VMBuilderTrait, MemoryTestUtilsTrait, native_token, setup_test_environment
    };
    use snforge_std::start_mock_call;

    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    #[test]
    fn test_identity_precompile() {
        let calldata = [0x2A].span();

        let (gas, result) = Identity::exec(calldata).unwrap();

        assert_eq!(calldata, result);
        assert_eq!(gas, 18);
    }


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    //TODO(sn-foundry): fix or delete
    #[test]
    fn test_identity_precompile_static_call() {
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x3F).unwrap(); // retOffset
        vm.stack.push(0x20).unwrap(); // argsSize
        vm.stack.push(0x1F).unwrap(); // argsOffset
        vm.stack.push(0x4).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        vm.memory.store_with_expansion(0x2A, 0x1F);

        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x3F);
        assert_eq!(result, 0x2A);
    }
}
