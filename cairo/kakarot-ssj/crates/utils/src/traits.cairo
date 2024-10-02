pub mod array;
pub mod bytes;
pub mod eth_address;
pub mod integer;

use core::array::SpanTrait;
use core::num::traits::{Zero, One};
use core::starknet::secp256_trait::{Signature};
use core::starknet::storage_access::{StorageBaseAddress, storage_address_from_base};
use core::starknet::{EthAddress, ContractAddress};
use crate::math::{Bitshift};
use evm::errors::{EVMError, ensure, TYPE_CONVERSION_ERROR};

pub impl DefaultSignature of Default<Signature> {
    #[inline(always)]
    fn default() -> Signature {
        Signature { r: 0, s: 0, y_parity: false, }
    }
}

pub impl SpanDefault<T, impl TDrop: Drop<T>> of Default<Span<T>> {
    #[inline(always)]
    fn default() -> Span<T> {
        array![].span()
    }
}

pub impl EthAddressDefault of Default<EthAddress> {
    #[inline(always)]
    fn default() -> EthAddress {
        0.try_into().unwrap()
    }
}

pub impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        0.try_into().unwrap()
    }
}

pub impl BoolIntoNumeric<T, +Zero<T>, +One<T>> of Into<bool, T> {
    #[inline(always)]
    fn into(self: bool) -> T {
        if self {
            One::<T>::one()
        } else {
            Zero::<T>::zero()
        }
    }
}

pub impl NumericIntoBool<T, +Drop<T>, +Zero<T>, +One<T>, +PartialEq<T>> of Into<T, bool> {
    #[inline(always)]
    fn into(self: T) -> bool {
        self != Zero::<T>::zero()
    }
}

pub impl EthAddressIntoU256 of Into<EthAddress, u256> {
    fn into(self: EthAddress) -> u256 {
        let intermediate: felt252 = self.into();
        intermediate.into()
    }
}

pub impl U256TryIntoContractAddress of TryInto<u256, ContractAddress> {
    fn try_into(self: u256) -> Option<ContractAddress> {
        let maybe_value: Option<felt252> = self.try_into();
        match maybe_value {
            Option::Some(value) => value.try_into(),
            Option::None => Option::None,
        }
    }
}

pub impl StorageBaseAddressIntoU256 of Into<StorageBaseAddress, u256> {
    fn into(self: StorageBaseAddress) -> u256 {
        let self: felt252 = storage_address_from_base(self).into();
        self.into()
    }
}

//TODO remove once merged in corelib
pub impl StorageBaseAddressPartialEq of PartialEq<StorageBaseAddress> {
    fn eq(lhs: @StorageBaseAddress, rhs: @StorageBaseAddress) -> bool {
        let lhs: felt252 = (*lhs).into();
        let rhs: felt252 = (*rhs).into();
        lhs == rhs
    }
    fn ne(lhs: @StorageBaseAddress, rhs: @StorageBaseAddress) -> bool {
        !(*lhs == *rhs)
    }
}

pub trait TryIntoResult<T, U> {
    fn try_into_result(self: T) -> Result<U, EVMError>;
}

pub impl SpanU8TryIntoResultEthAddress of TryIntoResult<Span<u8>, EthAddress> {
    fn try_into_result(mut self: Span<u8>) -> Result<EthAddress, EVMError> {
        let len = self.len();
        if len == 0 {
            return Result::Ok(0.try_into().unwrap());
        }
        ensure(!(len > 20), EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))?;
        let offset: u32 = len.into() - 1;
        let mut result: u256 = 0;
        for i in 0
            ..len {
                let byte: u256 = (*self.at(i)).into();
                result += byte.shl(8 * (offset - i).into());
            };
        let address: felt252 = result.try_into_result()?;

        Result::Ok(address.try_into().unwrap())
    }
}

pub impl EthAddressTryIntoResultContractAddress of TryIntoResult<ContractAddress, EthAddress> {
    fn try_into_result(self: ContractAddress) -> Result<EthAddress, EVMError> {
        let tmp: felt252 = self.into();
        tmp.try_into().ok_or(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
    }
}

pub impl U256TryIntoResult<U, +TryInto<u256, U>> of TryIntoResult<u256, U> {
    fn try_into_result(self: u256) -> Result<U, EVMError> {
        match self.try_into() {
            Option::Some(value) => Result::Ok(value),
            Option::None => Result::Err(EVMError::TypeConversionError(TYPE_CONVERSION_ERROR))
        }
    }
}

pub impl U8IntoEthAddress of Into<u8, EthAddress> {
    fn into(self: u8) -> EthAddress {
        let value: felt252 = self.into();
        value.try_into().unwrap()
    }
}

#[cfg(test)]
mod tests {
    use core::starknet::storage_access::storage_base_address_from_felt252;
    use crate::traits::{StorageBaseAddressPartialEq};

    #[test]
    fn test_eq_storage_base_address() {
        let val_1 = storage_base_address_from_felt252(0x01);

        assert_eq!(@val_1, @val_1)
    }

    #[test]
    fn test_ne_storage_base_address() {
        let val_1 = storage_base_address_from_felt252(0x01);
        let val_2 = storage_base_address_from_felt252(0x02);

        assert_ne!(@val_1, @val_2)
    }
}
