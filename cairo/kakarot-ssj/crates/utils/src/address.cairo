use core::array::ArrayTrait;
use core::starknet::EthAddress;
use core::traits::TryInto;
use crate::rlp::{RLPTrait, RLPItem};
use crate::traits::bytes::{ToBytes, U8SpanExTrait};
use crate::traits::eth_address::EthAddressExTrait;
use crate::traits::{TryIntoResult};

use evm::errors::EVMError;

/// Computes the address of the new account that needs to be created.
///
/// # Arguments
///
/// * `sender_address` - The address of the account that wants to create the new account.
/// * `sender_nonce` - The transaction count of the account that wants to create the new account.
///
/// # Returns
///
/// The computed address of the new account as an `EthAddress`.
pub fn compute_contract_address(sender_address: EthAddress, sender_nonce: u64) -> EthAddress {
    let mut sender_address: RLPItem = RLPItem::String(sender_address.to_bytes().span());
    let sender_nonce: RLPItem = RLPItem::String(sender_nonce.to_be_bytes());
    let computed_address = U8SpanExTrait::compute_keccak256_hash(
        RLPTrait::encode_sequence([sender_address, sender_nonce].span())
    );
    let canonical_address = computed_address & 0xffffffffffffffffffffffffffffffffffffffff;
    canonical_address.try_into().unwrap()
}


/// Computes the address of the new account that needs to be created, which is
/// based on the sender address, salt, and the bytecode.
///
/// # Arguments
///
/// * `sender_address` - The address of the account that wants to create the new account.
/// * `salt` - Address generation salt.
/// * `bytecode` - The bytecode of the new account to be created.
///
/// # Returns
///
/// A `Result` containing the computed address of the new account as an `EthAddress`,
/// or an `EVMError` if the conversion fails.
pub fn compute_create2_contract_address(
    sender_address: EthAddress, salt: u256, bytecode: Span<u8>
) -> Result<EthAddress, EVMError> {
    let hash = bytecode.compute_keccak256_hash().to_be_bytes_padded();

    let sender_address = sender_address.to_bytes().span();

    let salt = salt.to_be_bytes_padded();

    let mut preimage: Array<u8> = array![];

    preimage.append_span([0xff].span());
    preimage.append_span(sender_address);
    preimage.append_span(salt);
    preimage.append_span(hash);

    let address_hash = preimage.span().compute_keccak256_hash().to_be_bytes_padded();

    let address: EthAddress = address_hash.slice(12, 20).try_into_result()?;

    Result::Ok(address)
}

#[cfg(test)]
mod tests {
    use contracts::test_data::counter_evm_bytecode;
    use core::starknet::EthAddress;
    use crate::address::{compute_contract_address, compute_create2_contract_address};

    #[test]
    fn test_compute_create2_contract_address() {
        let bytecode = counter_evm_bytecode();
        let salt = 0xbeef;
        let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
            .try_into()
            .expect('Wrong Eth address');

        let address = compute_create2_contract_address(from, salt, bytecode)
            .expect('create2_contract_address fail');

        assert_eq!(address.into(), 0x088a44D7CdD8DEA4d1Db6E3F4059c70c405a0C97);
    }

    #[test]
    fn test_compute_contract_address() {
        let nonce = 420;
        let from: EthAddress = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
            .try_into()
            .expect('Wrong Eth address');

        let address = compute_contract_address(from, nonce);
        assert(
            address.into() == 0x40A633EeF249F21D95C8803b7144f19AAfeEF7ae, 'wrong create address'
        );
    }
}
