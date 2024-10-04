use core::starknet::EthAddress;
use crate::errors::{RLPError, EthTransactionError, RLPErrorTrait};
use crate::eth_transaction::common::{TxKind, TxKindTrait};
use crate::eth_transaction::eip1559::{TxEip1559, TxEip1559Trait};
use crate::eth_transaction::eip2930::{AccessListItem, TxEip2930, TxEip2930Trait};
use crate::eth_transaction::legacy::{TxLegacy, TxLegacyTrait};
use crate::eth_transaction::tx_type::{TxType};
use crate::rlp::{RLPItem, RLPTrait};
use crate::traits::bytes::U8SpanExTrait;
use crate::traits::{DefaultSignature};


#[derive(Copy, Debug, Drop, PartialEq, Serde)]
pub enum Transaction {
    /// Legacy transaction (type `0x0`).
    ///
    /// Traditional Ethereum transactions, containing parameters `nonce`, `gasPrice`, `gasLimit`,
    /// `to`, `value`, `data`, `v`, `r`, and `s`.
    ///
    /// These transactions do not utilize access lists nor do they incorporate EIP-1559 fee market
    /// changes.
    #[default]
    Legacy: TxLegacy,
    /// Transaction with an [`AccessList`] ([EIP-2930](https://eips.ethereum.org/EIPS/eip-2930)),
    /// type `0x1`.
    ///
    /// The `accessList` specifies an array of addresses and storage keys that the transaction
    /// plans to access, enabling gas savings on cross-contract calls by pre-declaring the accessed
    /// contract and storage slots.
    Eip2930: TxEip2930,
    /// A transaction with a priority fee ([EIP-1559](https://eips.ethereum.org/EIPS/eip-1559)),
    /// type `0x2`.
    ///
    /// Unlike traditional transactions, EIP-1559 transactions use an in-protocol, dynamically
    /// changing base fee per gas, adjusted at each block to manage network congestion.
    ///
    /// - `maxPriorityFeePerGas`, specifying the maximum fee above the base fee the sender is
    ///   willing to pay
    /// - `maxFeePerGas`, setting the maximum total fee the sender is willing to pay.
    ///
    /// The base fee is burned, while the priority fee is paid to the miner who includes the
    /// transaction, incentivizing miners to include transactions with higher priority fees per
    /// gas.
    Eip1559: TxEip1559,
}

#[generate_trait]
pub impl _Transasction of TransactionTrait {
    /// Get `chain_id`.
    fn chain_id(self: @Transaction) -> Option<u64> {
        match (*self) {
            Transaction::Legacy(tx) => tx.chain_id,
            Transaction::Eip2930(TxEip2930 { chain_id, .. }) |
            Transaction::Eip1559(TxEip1559 { chain_id, .. }) => Option::Some(chain_id),
        }
    }

    /// Gets the transaction's [`TxKind`], which is the address of the recipient or
    /// [`TxKind::Create`] if the transaction is a contract creation.
    fn kind(self: @Transaction) -> TxKind {
        match (*self) {
            Transaction::Legacy(TxLegacy { to, .. }) | Transaction::Eip2930(TxEip2930 { to, .. }) |
            Transaction::Eip1559(TxEip1559 { to, .. }) => to,
        }
    }

    /// Get the transaction's address of the contract that will be called, or the address that will
    /// receive the transfer.
    ///
    /// Returns `None` if this is a `CREATE` transaction.
    fn to(self: @Transaction) -> Option<EthAddress> {
        self.kind().to()
    }

    /// Get the transaction's type
    fn transaction_type(self: @Transaction) -> TxType {
        match (*self) {
            Transaction::Legacy(_) => TxType::Legacy,
            Transaction::Eip2930(_) => TxType::Eip2930,
            Transaction::Eip1559(_) => TxType::Eip1559,
        }
    }

    /// Gets the transaction's value field.
    fn value(self: @Transaction) -> u256 {
        match (*self) {
            Transaction::Legacy(TxLegacy { value, .. }) |
            Transaction::Eip2930(TxEip2930 { value, .. }) |
            Transaction::Eip1559(TxEip1559 { value, .. }) => value,
        }
    }

    /// Get the transaction's nonce.
    fn nonce(self: @Transaction) -> u64 {
        match (*self) {
            Transaction::Legacy(TxLegacy { nonce, .. }) |
            Transaction::Eip2930(TxEip2930 { nonce, .. }) |
            Transaction::Eip1559(TxEip1559 { nonce, .. }) => nonce,
        }
    }

    /// Returns the [`AccessList`] of the transaction.
    ///
    /// Returns `None` for legacy transactions.
    fn access_list(self: @Transaction) -> Option<Span<AccessListItem>> {
        match (*self) {
            Transaction::Eip2930(TxEip2930 { access_list, .. }) |
            Transaction::Eip1559(TxEip1559 { access_list, .. }) => Option::Some(access_list),
            _ => Option::None,
        }
    }

    /// Get the gas limit of the transaction.
    fn gas_limit(self: @Transaction) -> u64 {
        match (*self) {
            Transaction::Legacy(TxLegacy { gas_limit, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_limit, .. }) |
            Transaction::Eip1559(TxEip1559 { gas_limit, .. }) => gas_limit.try_into().unwrap(),
        }
    }

    /// Max fee per gas for eip1559 transaction, for legacy transactions this is `gas_price`.
    fn max_fee_per_gas(self: @Transaction) -> u128 {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_fee_per_gas, .. }) => max_fee_per_gas,
            Transaction::Legacy(TxLegacy { gas_price, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_price, .. }) => gas_price,
        }
    }

    /// Max priority fee per gas for eip1559 transaction, for legacy and eip2930 transactions this
    /// is `None`
    fn max_priority_fee_per_gas(self: @Transaction) -> Option<u128> {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_priority_fee_per_gas,
            .. }) => Option::Some(max_priority_fee_per_gas),
            _ => Option::None,
        }
    }

    /// Return the max priority fee per gas if the transaction is an EIP-1559 transaction, and
    /// otherwise return the gas price.
    ///
    /// # Warning
    ///
    /// This is different than the `max_priority_fee_per_gas` method, which returns `None` for
    /// non-EIP-1559 transactions.
    fn priority_fee_or_price(self: @Transaction) -> u128 {
        match (*self) {
            Transaction::Eip1559(TxEip1559 { max_priority_fee_per_gas,
            .. }) => max_priority_fee_per_gas,
            Transaction::Legacy(TxLegacy { gas_price, .. }) |
            Transaction::Eip2930(TxEip2930 { gas_price, .. }) => gas_price,
        }
    }

    /// Returns the effective gas price for the given base fee.
    ///
    /// If the transaction is a legacy or EIP2930 transaction, the gas price is returned.
    fn effective_gas_price(self: @Transaction, base_fee: Option<u128>) -> u128 {
        match (*self) {
            Transaction::Legacy(tx) => tx.gas_price,
            Transaction::Eip2930(tx) => tx.gas_price,
            Transaction::Eip1559(tx) => tx.effective_gas_price(base_fee)
        }
    }

    /// Get the transaction's input field.
    fn input(self: @Transaction) -> Span<u8> {
        match (*self) {
            Transaction::Legacy(tx) => tx.input,
            Transaction::Eip2930(tx) => tx.input,
            Transaction::Eip1559(tx) => tx.input,
        }
    }
}


#[derive(Copy, Drop, Debug, PartialEq)]
pub struct TransactionUnsigned {
    /// Transaction hash
    pub hash: u256,
    /// Raw transaction info
    pub transaction: Transaction,
}

#[generate_trait]
pub impl _TransactionUnsigned of TransactionUnsignedTrait {
    /// Decodes the "raw" format of transaction (similar to `eth_sendRawTransaction`).
    ///
    /// This should be used for any method that accepts a raw transaction.
    /// * `eth_send_raw_transaction`.
    ///
    /// A raw transaction is either a legacy transaction or EIP-2718 typed transaction.
    ///
    /// For legacy transactions, the format is encoded as: `rlp(tx-data)`. This format will start
    /// with a RLP list header.
    ///
    /// For EIP-2718 typed transactions, the format is encoded as the type of the transaction
    /// followed by the rlp of the transaction: `type || rlp(tx-data)`.
    ///
    /// Both for legacy and EIP-2718 transactions, an error will be returned if there is an excess
    /// of bytes in input data.
    fn decode_enveloped(
        ref tx_data: Span<u8>,
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        if tx_data.is_empty() {
            return Result::Err(EthTransactionError::RLPError(RLPError::InputTooShort));
        }

        // Check if it's a list
        let transaction_signed = if Self::is_legacy_tx(tx_data) {
            // Decode as a legacy transaction
            Self::decode_legacy_tx(ref tx_data)?
        } else {
            Self::decode_enveloped_typed_transaction(ref tx_data)?
        };

        //TODO: check that the entire input was consumed and that there are no extra bytes at the
        //end.

        Result::Ok(transaction_signed)
    }

    /// Decode a legacy Ethereum transaction
    /// This function decodes a legacy Ethereum transaction in accordance with EIP-155.
    /// It returns transaction details including nonce, gas price, gas limit, destination address,
    /// amount, payload, message hash, chain id. The transaction hash is computed by keccak hashing
    /// the signed transaction data, which includes the chain ID in accordance with EIP-155.
    /// # Arguments
    /// * encoded_tx_data - The raw rlp encoded transaction data
    /// * encoded_tx_data - is of the format: rlp![nonce, gasPrice, gasLimit, to , value, data,
    /// chainId, 0, 0]
    /// Note: this function assumes that tx_type has been checked to make sure it is a legacy
    /// transaction
    fn decode_legacy_tx(
        ref encoded_tx_data: Span<u8>
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        let rlp_decoded_data = RLPTrait::decode(encoded_tx_data);
        let mut rlp_decoded_data = rlp_decoded_data.map_err()?;

        if (rlp_decoded_data.len() != 1) {
            return Result::Err(
                EthTransactionError::TopLevelRlpListWrongLength(rlp_decoded_data.len())
            );
        }

        let rpl_item = *rlp_decoded_data.at(0);
        let legacy_tx: TxLegacy = match rpl_item {
            RLPItem::String => { Result::Err(EthTransactionError::ExpectedRLPItemToBeList)? },
            RLPItem::List(mut val) => {
                if (val.len() != 9) {
                    return Result::Err(EthTransactionError::LegacyTxWrongPayloadLength(val.len()));
                }
                TxLegacyTrait::decode_fields(ref val)?
            }
        };

        let tx_hash = Self::compute_hash(encoded_tx_data);

        Result::Ok(
            TransactionUnsigned { transaction: Transaction::Legacy(legacy_tx), hash: tx_hash, }
        )
    }

    /// Decodes an enveloped EIP-2718 typed transaction.
    ///
    /// This should _only_ be used internally in general transaction decoding methods,
    /// which have already ensured that the input is a typed transaction with the following format:
    /// `tx-type || rlp(tx-data)`
    ///
    /// Note that this format does not start with any RLP header, and instead starts with a single
    /// byte indicating the transaction type.
    ///
    /// CAUTION: this expects that `data` is `tx-type || rlp(tx-data)`
    fn decode_enveloped_typed_transaction(
        ref encoded_tx_data: Span<u8>
    ) -> Result<TransactionUnsigned, EthTransactionError> {
        // keep this around so we can use it to calculate the hash
        let original_data = encoded_tx_data;

        let tx_type = encoded_tx_data
            .pop_front()
            .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
        let tx_type: TxType = (*tx_type)
            .try_into()
            .ok_or(EthTransactionError::RLPError(RLPError::Custom('unsupported tx type')))?;

        let rlp_decoded_data = RLPTrait::decode(encoded_tx_data).map_err()?;
        if (rlp_decoded_data.len() != 1) {
            return Result::Err(
                EthTransactionError::RLPError(RLPError::Custom('not encoded as list'))
            );
        }

        let mut rlp_decoded_data = match *rlp_decoded_data.at(0) {
            RLPItem::String => {
                return Result::Err(
                    EthTransactionError::RLPError(RLPError::Custom('not encoded as list'))
                );
            },
            RLPItem::List(v) => { v }
        };

        let transaction = match tx_type {
            TxType::Eip2930 => Transaction::Eip2930(
                TxEip2930Trait::decode_fields(ref rlp_decoded_data)?
            ),
            TxType::Eip1559 => Transaction::Eip1559(
                TxEip1559Trait::decode_fields(ref rlp_decoded_data)?
            ),
            TxType::Legacy => {
                return Result::Err(
                    EthTransactionError::RLPError(RLPError::Custom('unexpected legacy tx type'))
                );
            }
        };

        let tx_hash = Self::compute_hash(original_data);
        Result::Ok(TransactionUnsigned { transaction, hash: tx_hash })
    }

    /// Returns the hash of the unsigned transaction
    ///
    /// The hash is used to recover the sender address when verifying the signature
    /// attached to the transaction
    #[inline(always)]
    fn compute_hash(encoded_tx_data: Span<u8>) -> u256 {
        encoded_tx_data.compute_keccak256_hash()
    }

    /// Check if a raw transaction is a legacy Ethereum transaction
    /// This function checks if a raw transaction is a legacy Ethereum transaction by checking the
    /// transaction type according to EIP-2718.
    /// # Arguments
    /// * `encoded_tx_data` - The raw rlp encoded transaction data
    #[inline(always)]
    fn is_legacy_tx(encoded_tx_data: Span<u8>) -> bool {
        // From EIP2718: if it starts with a value in the range [0xc0, 0xfe] then it is a legacy
        // transaction type
        if (*encoded_tx_data[0] > 0xbf && *encoded_tx_data[0] < 0xff) {
            return true;
        }

        return false;
    }
}

#[cfg(test)]
mod tests {
    use crate::eth_transaction::common::TxKind;
    use crate::eth_transaction::eip2930::AccessListItem;
    use crate::eth_transaction::tx_type::TxType;
    use crate::test_data::{
        legacy_rlp_encoded_tx, legacy_rlp_encoded_deploy_tx, eip_2930_encoded_tx,
        eip_1559_encoded_tx
    };
    use super::{TransactionTrait, TransactionUnsignedTrait};


    #[test]
    fn test_decode_legacy_tx() {
        // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0,
        // 0]
        // expected rlp decoding:  [ "0x", "0x3b9aca00", "0x1e8480",
        // "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef",
        // "0x4b4b5254", "0x", "0x" ]
        // message_hash: 0xcf71743e6e25fef715398915997f782b95554c8bbfb7b3f7701e007332ed31b4
        // chain id used: 'KKRT'
        let mut encoded_tx_data = legacy_rlp_encoded_tx();
        let decoded = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx_data).unwrap();
        assert_eq!(decoded.transaction.nonce(), 0);
        assert_eq!(decoded.transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(decoded.transaction.gas_limit(), 0x1e8480);
        assert_eq!(
            decoded.transaction.kind(),
            TxKind::Call(0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap())
        );
        assert_eq!(decoded.transaction.value(), 0x016345785d8a0000);
        assert_eq!(decoded.transaction.input(), [0xab, 0xcd, 0xef].span());
        assert_eq!(decoded.transaction.chain_id(), Option::Some(0x4b4b5254));
        assert_eq!(decoded.transaction.transaction_type(), TxType::Legacy);
    }

    #[test]
    fn test_decode_deploy_tx() {
        // tx_format (EIP-155, unsigned): [nonce, gasPrice, gasLimit, to, value, data, chainId, 0,
        // 0]
        // expected rlp decoding:
        // ["0x","0x0a","0x061a80","0x","0x0186a0","0x600160010a5060006000f3","0x4b4b5254","0x","0x"]
        let mut encoded_tx_data = legacy_rlp_encoded_deploy_tx();
        let decoded = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx_data).unwrap();
        assert_eq!(decoded.transaction.nonce(), 0);
        assert_eq!(decoded.transaction.max_fee_per_gas(), 0x0a);
        assert_eq!(decoded.transaction.gas_limit(), 0x061a80);
        assert_eq!(decoded.transaction.kind(), TxKind::Create);
        assert_eq!(decoded.transaction.value(), 0x0186a0);
        assert_eq!(
            decoded.transaction.input(),
            [0x60, 0x01, 0x60, 0x01, 0x0a, 0x50, 0x60, 0x00, 0x60, 0x00, 0xf3].span()
        );
        assert_eq!(decoded.transaction.chain_id(), Option::Some(0x4b4b5254));
        assert_eq!(decoded.transaction.transaction_type(), TxType::Legacy);
    }

    #[test]
    fn test_decode_eip2930_tx() {
        // tx_format (EIP-2930, unsigned): 0x01  || rlp([chainId, nonce, gasPrice, gasLimit, to,
        // value, data, accessList])
        // expected rlp decoding:   [ "0x4b4b5254", "0x", "0x3b9aca00", "0x1e8480",
        // "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef",
        // [["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        // ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65",
        // "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ]
        // message_hash: 0xc00f61dcc99a78934275c404267b9d035cad7f71cf3ae2ed2c5a55b601a5c107
        // chain id used: 'KKRT'

        let mut encoded_tx_data = eip_2930_encoded_tx();
        let decoded = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx_data).unwrap();
        assert_eq!(decoded.transaction.chain_id(), Option::Some(0x4b4b5254));
        assert_eq!(decoded.transaction.nonce(), 0);
        assert_eq!(decoded.transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(decoded.transaction.gas_limit(), 0x1e8480);
        assert_eq!(
            decoded.transaction.kind(),
            TxKind::Call(0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap())
        );
        assert_eq!(decoded.transaction.value(), 0x016345785d8a0000);
        assert_eq!(decoded.transaction.input(), [0xab, 0xcd, 0xef].span());
        assert_eq!(decoded.transaction.transaction_type(), TxType::Eip2930);
    }

    #[test]
    fn test_decode_eip1559_tx() {
        // tx_format (EIP-1559, unsigned):  0x02 || rlp([chain_id, nonce, max_priority_fee_per_gas,
        // max_fee_per_gas, gas_limit, destination, amount, data, access_list])
        // expected rlp decoding: [ "0x4b4b5254", "0x", "0x", "0x3b9aca00", "0x1e8480",
        // "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984", "0x016345785d8a0000", "0xabcdef",
        // [[["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        // ["0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65",
        // "0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94"]]] ] ]
        // message_hash: 0xa2de478d0c94b4be637523b818d03b6a1841fca63fd044976fcdbef3c57a87b0
        // chain id used: 'KKRT'

        let mut encoded_tx_data = eip_1559_encoded_tx();
        let decoded = TransactionUnsignedTrait::decode_enveloped(ref encoded_tx_data).unwrap();
        assert_eq!(decoded.transaction.chain_id(), Option::Some(0x4b4b5254));
        assert_eq!(decoded.transaction.nonce(), 0);
        assert_eq!(decoded.transaction.max_fee_per_gas(), 0x3b9aca00);
        assert_eq!(decoded.transaction.gas_limit(), 0x1e8480);
        assert_eq!(
            decoded.transaction.kind(),
            TxKind::Call(0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap())
        );
        assert_eq!(decoded.transaction.value(), 0x016345785d8a0000);
        assert_eq!(decoded.transaction.input(), [0xab, 0xcd, 0xef].span());
        let expected_access_list = [
            AccessListItem {
                ethereum_address: 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984.try_into().unwrap(),
                storage_keys: [
                    0xde9fbe35790b85c23f42b7430c78f122636750cc217a534c80a9a0520969fa65,
                    0xd5362e94136f76bfc8dad0b510b94561af7a387f1a9d0d45e777c11962e5bd94
                ].span()
            }
        ].span();
        assert_eq!(
            decoded.transaction.access_list().expect('access_list is none'), expected_access_list
        );
        assert_eq!(decoded.transaction.transaction_type(), TxType::Eip1559);
    }

    #[test]
    fn test_is_legacy_tx_eip_155_tx() {
        let encoded_tx_data = legacy_rlp_encoded_tx();
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(result, 'is_legacy_tx expected true');
    }

    #[test]
    fn test_is_legacy_tx_eip_1559_tx() {
        let encoded_tx_data = eip_1559_encoded_tx();
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }

    #[test]
    fn test_is_legacy_tx_eip_2930_tx() {
        let encoded_tx_data = eip_2930_encoded_tx();
        let result = TransactionUnsignedTrait::is_legacy_tx(encoded_tx_data);

        assert(!result, 'is_legacy_tx expected false');
    }
}
