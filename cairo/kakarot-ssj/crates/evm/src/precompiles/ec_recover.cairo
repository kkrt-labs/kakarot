use core::starknet::secp256_trait::{Signature, recover_public_key, Secp256PointTrait};
use core::starknet::{
    EthAddress, eth_signature::{public_key_point_to_eth_address}, secp256k1::{Secp256k1Point},
    SyscallResultTrait
};
use core::traits::Into;
use crate::errors::EVMError;
use crate::precompiles::Precompile;
use utils::traits::EthAddressIntoU256;
use utils::traits::bytes::{U8SpanExTrait, FromBytes, ToBytes};
use utils::traits::{NumericIntoBool, BoolIntoNumeric};

const EC_RECOVER_PRECOMPILE_GAS_COST: u64 = 3000;

pub impl EcRecover of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x1.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = EC_RECOVER_PRECOMPILE_GAS_COST;

        // Pad the input to 128 bytes to avoid out-of-bounds accesses
        let input = input.pad_right_with_zeroes(128);
        let message_hash = input.slice(0, 32);
        let message_hash = match message_hash.from_be_bytes() {
            Option::Some(message_hash) => message_hash,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let v: Option<u256> = input.slice(32, 32).from_be_bytes();
        let y_parity = match v {
            Option::Some(v) => {
                if !(v == 27 || v == 28) {
                    return Result::Ok((gas, [].span()));
                }
                let y_parity = v - 27; //won't overflow because v is 27 or 28
                y_parity.into()
            },
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let r: Option<u256> = input.slice(64, 32).from_be_bytes();
        let r = match r {
            Option::Some(r) => r,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let s: Option<u256> = input.slice(96, 32).from_be_bytes();
        let s = match s {
            Option::Some(s) => s,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let signature = Signature { r, s, y_parity };

        let recovered_public_key =
            match recover_public_key::<Secp256k1Point>(message_hash, signature) {
            Option::Some(public_key_point) => {
                // EVM spec requires that the public key is not the point at infinity
                let (x, y) = public_key_point.get_coordinates().unwrap_syscall();
                if (x == 0 && y == 0) {
                    return Result::Ok((gas, [].span()));
                }
                public_key_point
            },
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let eth_address: u256 = public_key_point_to_eth_address(recovered_public_key).into();
        let eth_address = eth_address.to_be_bytes_padded();

        return Result::Ok((gas, eth_address));
    }
}

#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use crate::instructions::SystemOperationsTrait;
    use crate::memory::MemoryTrait;

    use crate::precompiles::ec_recover::EcRecover;
    use crate::stack::StackTrait;
    use crate::test_utils::setup_test_environment;
    use crate::test_utils::{VMBuilderTrait, MemoryTestUtilsTrait, native_token};
    use snforge_std::start_mock_call;
    use utils::traits::bytes::{ToBytes, FromBytes};


    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='jFirsNplace_parameters%20in%20memoryZ456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3whash~Y~28wvX2YZ9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608wrX4YZ4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852adawsX6YqqjDo_call~32JSizeX80JOffsetX8VSize~VOffset~1waddressW4QFFFFFFFFwgasqSTATICCALLqqjPut_resulNalonKon_stackqPOPX80qMLOAD'~W1%20w%20jq%5Cnj//%20_%20thKZW32QY0qMSTOREX~0xWqPUSHV0wargsQ%200xNt%20Ke%20Jwret%01JKNQVWXYZ_jqw~_>
    #[test]
    fn test_ec_recover_precompile() {
        let msg_hash = 0x456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3_u256
            .to_be_bytes_padded();
        let v = 28_u256.to_be_bytes_padded();
        let r = 0x9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608_u256
            .to_be_bytes_padded();
        let s = 0x4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(v);
        calldata.append_span(r);
        calldata.append_span(s);

        let (gas, result) = EcRecover::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().unwrap();
        assert_eq!(result, 0x7156526fbd7a3c72969b54f64e42c10fbb768c8a);
        assert_eq!(gas, 3000);
    }

    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='jFirsNplace_parameters%20in%20memoryZ456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3whash~Y~28wvX2YZ9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608wrX4YZ4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852adawsX6YqqjDo_call~32JSizeX80JOffsetX8VSize~VOffset~1waddressW4QFFFFFFFFwgasqSTATICCALLqqjPut_resulNalonKon_stackqPOPX80qMLOAD'~W1%20w%20jq%5Cnj//%20_%20thKZW32QY0qMSTOREX~0xWqPUSHV0wargsQ%200xNt%20Ke%20Jwret%01JKNQVWXYZ_jqw~_>
    #[test]
    fn test_ec_precompile_static_call() {
        setup_test_environment();
        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .memory
            .store(
                0x456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3, 0x0
            ); // msg_hash
        vm.memory.store_with_expansion(0x1C, 0x20); // v
        vm
            .memory
            .store(0x9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608, 0x40); // r
        vm
            .memory
            .store(0x4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada, 0x60); // s

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0x80).unwrap(); // retOffset
        vm.stack.push(0x80).unwrap(); // argsSize
        vm.stack.push(0x0).unwrap(); // argsOffset
        vm.stack.push(0x1).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        start_mock_call::<u256>(native_token(), selector!("balance_of"), 0);
        vm.exec_staticcall().unwrap();

        let result = vm.memory.load(0x80);
        assert_eq!(result, 0x7156526fbd7a3c72969b54f64e42c10fbb768c8a);
    }
}
