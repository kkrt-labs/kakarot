use core::starknet::SyscallResultTrait;
use core::starknet::secp256_trait::{Secp256Trait};
use core::starknet::{EthAddress, secp256r1::{Secp256r1Point}, secp256_trait::is_valid_signature};
use crate::errors::{EVMError};
use crate::precompiles::Precompile;
use utils::traits::bytes::FromBytes;

const P256VERIFY_PRECOMPILE_GAS_COST: u64 = 3450;

const ONE_32_BYTES: [
    u8
    ; 32] = [
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
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01
];

pub impl P256Verify of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x100.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = P256VERIFY_PRECOMPILE_GAS_COST;

        if input.len() != 160 {
            return Result::Ok((gas, [].span()));
        }

        let message_hash = input.slice(0, 32);
        let message_hash = match message_hash.from_be_bytes() {
            Option::Some(message_hash) => message_hash,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let r: Option<u256> = input.slice(32, 32).from_be_bytes();
        let r = match r {
            Option::Some(r) => r,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let s: Option<u256> = input.slice(64, 32).from_be_bytes();
        let s = match s {
            Option::Some(s) => s,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let x: Option<u256> = input.slice(96, 32).from_be_bytes();
        let x = match x {
            Option::Some(x) => x,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let y: Option<u256> = input.slice(128, 32).from_be_bytes();
        let y = match y {
            Option::Some(y) => y,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        let public_key: Option<Secp256r1Point> = Secp256Trait::secp256_ec_new_syscall(x, y)
            .unwrap_syscall();
        let public_key = match public_key {
            Option::Some(public_key) => public_key,
            Option::None => { return Result::Ok((gas, [].span())); }
        };

        if !is_valid_signature(message_hash, r, s, public_key) {
            return Result::Ok((gas, [].span()));
        }

        return Result::Ok((gas, ONE_32_BYTES.span()));
    }
}

#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use crate::instructions::SystemOperationsTrait;
    use crate::memory::MemoryTrait;

    use crate::precompiles::p256verify::P256Verify;
    use crate::stack::StackTrait;
    use crate::test_utils::{VMBuilderTrait};
    use crate::test_utils::{setup_test_environment, native_token};
    use snforge_std::start_mock_call;
    use utils::traits::bytes::{ToBytes, FromBytes};


    // source:
    // <https://github.com/ethereum/go-ethereum/pull/27540/files#diff-3548292e7ee4a75fc8146397c6baf5c969f6fe6cd9355df322cdb4f11103e004>
    #[test]
    fn test_p256verify_precompile() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();
        let y = 0x7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);
        calldata.append_span(y);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().expect('p256verify_precompile_test');
        assert_eq!(result, 0x01);
        assert_eq!(gas, 3450);
    }

    // source:
    // <https://github.com/ethereum/go-ethereum/pull/27540/files#diff-3548292e7ee4a75fc8146397c6baf5c969f6fe6cd9355df322cdb4f11103e004>
    #[test]
    //TODO(sn-foundry): fix or delete
    fn test_p256verify_precompile_static_call() {
        setup_test_environment();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .memory
            .store(
                0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d, 0x0
            ); // msg_hash
        vm
            .memory
            .store(0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac, 0x20); // r
        vm
            .memory
            .store(0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60, 0x40); // s
        vm
            .memory
            .store(0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3, 0x60); // x
        vm
            .memory
            .store(0x7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e, 0x80); // y

        vm.stack.push(0x20).unwrap(); // retSize
        vm.stack.push(0xa0).unwrap(); // retOffset
        vm.stack.push(0xa0).unwrap(); // argsSize
        vm.stack.push(0x0).unwrap(); // argsOffset
        vm.stack.push(0x100).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        vm.exec_staticcall().unwrap();

        let mut result = Default::default();
        vm.memory.load_n(0x20, ref result, 0xa0);

        assert_eq!(result.span(), super::ONE_32_BYTES.span());
    }

    #[test]
    fn test_p256verify_precompile_input_too_short() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        assert_eq!(result, [].span());
        assert_eq!(gas, 3450);
    }

    //TODO(sn-foundry): fix or delete
    #[test]
    fn test_p256verify_precompile_input_too_short_static_call() {
        setup_test_environment();

        let mut vm = VMBuilderTrait::new_with_presets().build();

        vm
            .memory
            .store(
                0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d, 0x0
            ); // msg_hash
        vm
            .memory
            .store(0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac, 0x20); // r
        vm
            .memory
            .store(0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60, 0x40); // s
        vm
            .memory
            .store(0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3, 0x60); // x

        vm.stack.push(0x01).unwrap(); // retSize
        vm.stack.push(0x80).unwrap(); // retOffset
        vm.stack.push(0x80).unwrap(); // argsSize
        vm.stack.push(0x0).unwrap(); // argsOffset
        vm.stack.push(0x100).unwrap(); // address
        vm.stack.push(0xFFFFFFFF).unwrap(); // gas

        start_mock_call::<u256>(native_token(), selector!("balanceOf"), 0);
        vm.exec_staticcall().unwrap();

        let mut result = Default::default();
        vm.memory.load_n(0x1, ref result, 0x80);

        assert_eq!(result, array![0]);
    }
}
