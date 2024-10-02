use crate::eth_transaction::common::TxKind;
use crate::traits::SpanDefault;


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
