/// Transaction Type
#[derive(Copy, Drop, Debug, PartialEq)]
pub enum TxType {
    /// Legacy transaction pre EIP-2929
    #[default]
    Legacy,
    /// AccessList transaction
    Eip2930,
    /// Transaction with Priority fee
    Eip1559,
}


impl _TryInto of TryInto<u8, TxType> {
    fn try_into(self: u8) -> Option<TxType> {
        match self {
            0 => Option::Some(TxType::Legacy),
            1 => Option::Some(TxType::Eip2930),
            2 => Option::Some(TxType::Eip1559),
            _ => Option::None,
        }
    }
}
