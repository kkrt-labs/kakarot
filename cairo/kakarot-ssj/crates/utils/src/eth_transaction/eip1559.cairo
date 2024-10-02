use core::num::traits::SaturatingSub;
use crate::errors::{EthTransactionError, RLPError, RLPErrorTrait};
use crate::eth_transaction::common::TxKind;
use crate::eth_transaction::eip2930::AccessListItem;
use crate::rlp::{RLPItem, RLPHelpersTrait};
use crate::traits::SpanDefault;

/// A transaction with a priority fee ([EIP-1559](https://eips.ethereum.org/EIPS/eip-1559)).
#[derive(Copy, Drop, Debug, Default, PartialEq, Serde)]
pub struct TxEip1559 {
    /// EIP-155: Simple replay attack protection
    pub chain_id: u64,
    /// A scalar value equal to the number of transactions sent by the sender
    pub nonce: u64,
    /// A scalar value equal to the maximum
    /// amount of gas that should be used in executing
    /// this transaction. This is paid up-front, before any
    /// computation is done and may not be increased
    /// later;
    pub gas_limit: u64,
    /// A scalar value equal to the maximum
    /// amount of gas that should be used in executing
    /// this transaction. This is paid up-front, before any
    /// computation is done and may not be increased
    /// later;
    ///
    /// As ethereum circulation is around 120mil eth as of 2022 that is around
    /// 120000000000000000000000000 wei we are safe to use u128 as its max number is:
    /// 340282366920938463463374607431768211455
    ///
    pub max_fee_per_gas: u128,
    /// Max Priority fee that transaction is paying
    ///
    /// As ethereum circulation is around 120mil eth as of 2022 that is around
    /// 120000000000000000000000000 wei we are safe to use u128 as its max number is:
    /// 340282366920938463463374607431768211455
    ///
    pub max_priority_fee_per_gas: u128,
    /// The 160-bit address of the message call’s recipient or, for a contract creation
    /// transaction, ∅
    pub to: TxKind,
    /// A scalar value equal to the number of Wei to
    /// be transferred to the message call’s recipient or,
    /// in the case of contract creation, as an endowment
    /// to the newly created account;
    pub value: u256,
    /// The accessList specifies a list of addresses and storage keys;
    /// these addresses and storage keys are added into the `accessed_addresses`
    /// and `accessed_storage_keys` global sets (introduced in EIP-2929).
    /// A gas cost is charged, though at a discount relative to the cost of
    /// accessing outside the list.
    pub access_list: Span<AccessListItem>,
    /// Input has two uses depending if transaction is Create or Call (if `to` field is None or
    /// Some). pub init: An unlimited size byte array specifying the
    /// EVM-code for the account initialisation procedure CREATE,
    /// data: An unlimited size byte array specifying the
    /// input data of the message call, formally Td.
    pub input: Span<u8>,
}

#[generate_trait]
pub impl _impl of TxEip1559Trait {
    /// Returns the effective gas price for the given `base_fee`.
    ///
    /// # Arguments
    ///
    /// * `base_fee` - The current network base fee, if available
    ///
    /// # Returns
    ///
    /// The effective gas price as a u128
    fn effective_gas_price(self: @TxEip1559, base_fee: Option<u128>) -> u128 {
        match base_fee {
            Option::Some(base_fee) => {
                let tip = (*self.max_fee_per_gas).saturating_sub(base_fee);
                if tip > (*self.max_priority_fee_per_gas) {
                    (*self.max_priority_fee_per_gas) + base_fee
                } else {
                    *self.max_fee_per_gas
                }
            },
            Option::None => { *self.max_fee_per_gas }
        }
    }

    /// Decodes the RLP-encoded fields into a TxEip1559 struct.
    ///
    /// # Arguments
    ///
    /// * `data` - A span of RLPItems containing the encoded transaction fields
    ///
    /// # Returns
    ///
    /// A Result containing either the decoded TxEip1559 struct or an EthTransactionError
    fn decode_fields(ref data: Span<RLPItem>) -> Result<TxEip1559, EthTransactionError> {
        let boxed_fields = data
            .multi_pop_front::<9>()
            .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
        let [
            chain_id_encoded,
            nonce_encoded,
            max_priority_fee_per_gas_encoded,
            max_fee_per_gas_encoded,
            gas_limit_encoded,
            to_encoded,
            value_encoded,
            input_encoded,
            access_list_encoded
        ] =
            (*boxed_fields)
            .unbox();

        let chain_id = chain_id_encoded.parse_u64_from_string().map_err()?;
        let nonce = nonce_encoded.parse_u64_from_string().map_err()?;
        let max_priority_fee_per_gas = max_priority_fee_per_gas_encoded
            .parse_u128_from_string()
            .map_err()?;
        let max_fee_per_gas = max_fee_per_gas_encoded.parse_u128_from_string().map_err()?;
        let gas_limit = gas_limit_encoded.parse_u64_from_string().map_err()?;
        let to = to_encoded.try_parse_address_from_string().map_err()?;
        let value = value_encoded.parse_u256_from_string().map_err()?;
        let input = input_encoded.parse_bytes_from_string().map_err()?;
        let access_list = access_list_encoded.parse_access_list().map_err()?;

        let txkind_to = match to {
            Option::Some(to) => { TxKind::Call(to) },
            Option::None => { TxKind::Create }
        };

        Result::Ok(
            TxEip1559 {
                chain_id,
                nonce,
                max_priority_fee_per_gas,
                max_fee_per_gas,
                gas_limit,
                to: txkind_to,
                value,
                access_list,
                input,
            }
        )
    }
}
