// LENGTH
pub const RLP_EMPTY_INPUT: felt252 = 'KKT: EmptyInput';
pub const RLP_INPUT_TOO_SHORT: felt252 = 'KKT: InputTooShort';

#[derive(Drop, Copy, PartialEq, Debug)]
pub enum RLPError {
    EmptyInput,
    InputTooShort,
    InvalidInput,
    Custom: felt252,
    NotAString,
    FailedParsingU128,
    FailedParsingU256,
    FailedParsingAddress,
    FailedParsingAccessList,
    NotAList
}


pub impl RLPErrorIntoU256 of Into<RLPError, u256> {
    fn into(self: RLPError) -> u256 {
        match self {
            RLPError::EmptyInput => 'input is null'.into(),
            RLPError::InputTooShort => 'input too short'.into(),
            RLPError::InvalidInput => 'rlp input not conform'.into(),
            RLPError::Custom(msg) => msg.into(),
            RLPError::NotAString => 'rlp input is not a string'.into(),
            RLPError::FailedParsingU128 => 'rlp failed parsing u128'.into(),
            RLPError::FailedParsingU256 => 'rlp failed parsing u256'.into(),
            RLPError::FailedParsingAddress => 'rlp failed parsing address'.into(),
            RLPError::FailedParsingAccessList => 'rlp failed parsing access_list'.into(),
            RLPError::NotAList => 'rlp input is not a list'.into()
        }
    }
}

#[generate_trait]
pub impl RLPErrorImpl<T> of RLPErrorTrait<T> {
    fn map_err(self: Result<T, RLPError>) -> Result<T, EthTransactionError> {
        match self {
            Result::Ok(val) => Result::Ok(val),
            Result::Err(error) => { Result::Err(EthTransactionError::RLPError(error)) }
        }
    }
}

#[derive(Drop, Copy, PartialEq, Debug)]
pub enum EthTransactionError {
    RLPError: RLPError,
    ExpectedRLPItemToBeList,
    ExpectedRLPItemToBeString,
    TransactionTypeError,
    // the usize represents the encountered length of payload
    TopLevelRlpListWrongLength: usize,
    // the usize represents the encountered length of payload
    LegacyTxWrongPayloadLength: usize,
    // the usize represents the encountered length of payload
    TypedTxWrongPayloadLength: usize,
    IncorrectChainId,
    IncorrectAccountNonce,
    /// If the transaction's fee is less than the base fee of the block
    FeeCapTooLow,
    /// Thrown to ensure no one is able to specify a transaction with a tip higher than the total
    /// fee cap.
    TipAboveFeeCap,
    /// Thrown to ensure no one is able to specify a transaction with a tip that is too high.
    TipVeryHigh,
    Other: felt252
}
