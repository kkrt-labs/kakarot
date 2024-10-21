use crate::errors::{RLPError, EthTransactionError, RLPErrorTrait};
use crate::eth_transaction::common::TxKind;
use crate::rlp::{RLPItem, RLPHelpersTrait};
use crate::traits::SpanDefault;
use crate::traits::{DefaultSignature};


#[derive(Copy, Drop, Debug, Default, PartialEq, Serde)]
pub struct TxLegacy {
    /// Added as EIP-155: Simple replay attack protection
    pub chain_id: Option<u64>,
    /// A scalar value equal to the number of transactions sent by the sender; formally Tn.
    pub nonce: u64,
    /// A scalar value equal to the number of
    /// Wei to be paid per unit of gas for all computation
    /// costs incurred as a result of the execution of this transaction; formally Tp.
    ///
    /// As ethereum circulation is around 120mil eth as of 2022 that is around
    /// 120000000000000000000000000 wei we are safe to use u128 as its max number is:
    /// 340282366920938463463374607431768211455
    pub gas_price: u128,
    /// A scalar value equal to the maximum
    /// amount of gas that should be used in executing
    /// this transaction. This is paid up-front, before any
    /// computation is done and may not be increased
    /// later;
    pub gas_limit: u64,
    /// The 160-bit address of the message call’s recipient or, for a contract creation
    /// transaction, ∅.
    pub to: TxKind,
    /// A scalar value equal to the number of Wei to
    /// be transferred to the message call’s recipient or,
    /// in the case of contract creation, as an endowment
    /// to the newly created account;
    pub value: u256,
    /// Input has two uses depending if transaction is Create or Call (if `to` field is None or
    /// Some). pub init: An unlimited size byte array specifying the
    /// EVM-code for the account initialisation procedure CREATE,
    /// data: An unlimited size byte array specifying the
    /// input data of the message call.
    pub input: Span<u8>,
}

#[generate_trait]
pub impl _impl of TxLegacyTrait {
    /// Decodes the RLP-encoded fields into a TxLegacy struct.
    ///
    /// # Arguments
    ///
    /// * `data` - A span of RLPItems containing the encoded transaction fields
    ///
    /// # Returns
    ///
    /// A Result containing either the decoded TxLegacy struct or an EthTransactionError
    fn decode_fields(ref data: Span<RLPItem>) -> Result<TxLegacy, EthTransactionError> {
        let boxed_fields = data
            .multi_pop_front::<7>()
            .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
        let [
            nonce_encoded,
            gas_price_encoded,
            gas_limit_encoded,
            to_encoded,
            value_encoded,
            input_encoded,
            chain_id_encoded
        ] =
            (*boxed_fields)
            .unbox();

        let nonce = nonce_encoded.parse_u64_from_string().map_err()?;
        let gas_price = gas_price_encoded.parse_u128_from_string().map_err()?;
        let gas_limit = gas_limit_encoded.parse_u64_from_string().map_err()?;
        let to = to_encoded.try_parse_address_from_string().map_err()?;
        let value = value_encoded.parse_u256_from_string().map_err()?;
        let input = input_encoded.parse_bytes_from_string().map_err()?;
        let chain_id = chain_id_encoded.parse_u64_from_string().map_err()?;

        let transact_to = match to {
            Option::Some(to) => { TxKind::Call(to) },
            Option::None => { TxKind::Create }
        };

        Result::Ok(
            TxLegacy {
                nonce,
                gas_price,
                gas_limit,
                to: transact_to,
                value,
                input,
                chain_id: Option::Some(chain_id),
            }
        )
    }
}
