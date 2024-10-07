use core::starknet::EthAddress;

/// The `to` field of a transaction. Either a target address, or empty for a
/// contract creation.
#[derive(Copy, Drop, Debug, Default, PartialEq, Serde)]
pub enum TxKind {
    /// A transaction that creates a contract.
    #[default]
    Create,
    /// A transaction that calls a contract or transfer.
    Call: EthAddress,
}

impl OptionAddressIntoTxKind of Into<Option<EthAddress>, TxKind> {
    fn into(self: Option<EthAddress>) -> TxKind {
        match self {
            Option::None => TxKind::Create,
            Option::Some(address) => TxKind::Call(address),
        }
    }
}

impl AddressIntoTxKind of Into<EthAddress, TxKind> {
    fn into(self: EthAddress) -> TxKind {
        TxKind::Call(self)
    }
}

#[generate_trait]
pub impl TxKindImpl of TxKindTrait {
    fn is_create(self: @TxKind) -> bool {
        match self {
            TxKind::Create => true,
            TxKind::Call(_) => false,
        }
    }

    fn is_call(self: @TxKind) -> bool {
        match self {
            TxKind::Create => false,
            TxKind::Call(_) => true,
        }
    }

    fn to(self: @TxKind) -> Option<EthAddress> {
        match self {
            TxKind::Create => Option::None,
            TxKind::Call(address) => Option::Some(*address),
        }
    }
}
