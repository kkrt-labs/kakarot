use core::starknet::EthAddress;
use crate::errors::{EthTransactionError, RLPError, RLPErrorTrait};
use crate::eth_transaction::common::TxKind;
use crate::rlp::{RLPItem, RLPHelpersTrait};
use crate::traits::SpanDefault;


#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct AccessListItem {
    pub ethereum_address: EthAddress,
    pub storage_keys: Span<u256>
}

#[generate_trait]
pub impl AccessListItemImpl of AccessListItemTrait {
    fn to_storage_keys(self: @AccessListItem) -> Span<(EthAddress, u256)> {
        let AccessListItem { ethereum_address, mut storage_keys } = *self;

        let mut storage_keys_arr = array![];
        for storage_key in storage_keys {
            storage_keys_arr.append((ethereum_address, *storage_key));
        };

        storage_keys_arr.span()
    }
}


/// Transaction with an [`AccessList`] ([EIP-2930](https://eips.ethereum.org/EIPS/eip-2930)).
#[derive(Copy, Drop, Debug, Default, PartialEq, Serde)]
pub struct TxEip2930 {
    /// Added as EIP-pub 155: Simple replay attack protection
    pub chain_id: u64,
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
    /// later; formally Tg.
    pub gas_limit: u64,
    /// The 160-bit address of the message call’s recipient or, for a contract creation
    /// transaction, ∅, used here to denote the only member of B0 ; formally Tt.
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
    /// input data of the message call;
    pub input: Span<u8>,
}


#[generate_trait]
pub impl _impl of TxEip2930Trait {
    /// Decodes the RLP-encoded fields into a TxEip2930 struct.
    ///
    /// # Arguments
    ///
    /// * `data` - A span of RLPItems containing the encoded transaction fields
    ///
    /// # Returns
    ///
    /// A Result containing either the decoded TxEip2930 struct or an EthTransactionError
    fn decode_fields(ref data: Span<RLPItem>) -> Result<TxEip2930, EthTransactionError> {
        let boxed_fields = data
            .multi_pop_front::<8>()
            .ok_or(EthTransactionError::RLPError(RLPError::InputTooShort))?;
        let [
            chain_id_encoded,
            nonce_encoded,
            gas_price_encoded,
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
        let gas_price = gas_price_encoded.parse_u128_from_string().map_err()?;
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
            TxEip2930 {
                chain_id: chain_id,
                nonce,
                gas_price,
                gas_limit,
                input,
                access_list,
                to: txkind_to,
                value,
            }
        )
    }
}
