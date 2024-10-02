pub mod common;
pub mod eip1559;
pub mod eip2930;
pub mod legacy;
pub mod transaction;
pub mod tx_type;
use crate::errors::{EthTransactionError, RLPErrorImpl};
use crate::traits::bytes::ByteArrayExt;


/// Checks the effective gas price of a transaction as specified in EIP-1559 with relevant checks.
///
/// # Arguments
///
/// * `max_fee_per_gas` - The maximum fee per gas the user is willing to pay.
/// * `max_priority_fee_per_gas` - The maximum priority fee per gas the user is willing to pay
/// (optional).
/// * `block_base_fee` - The base fee per gas for the current block.
///
/// # Returns
///
/// * `Result<(), EthTransactionError>` - Ok if the gas fee is valid, or an error if not.
pub fn check_gas_fee(
    max_fee_per_gas: u128, max_priority_fee_per_gas: Option<u128>, block_base_fee: u128,
) -> Result<(), EthTransactionError> {
    let max_priority_fee_per_gas = max_priority_fee_per_gas.unwrap_or(0);

    if max_fee_per_gas < block_base_fee {
        // `base_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::FeeCapTooLow);
    }
    if max_fee_per_gas < max_priority_fee_per_gas {
        // `max_priority_fee_per_gas` is greater than the `max_fee_per_gas`
        return Result::Err(EthTransactionError::TipAboveFeeCap);
    }

    Result::Ok(())
}

#[cfg(test)]
mod tests {
    use crate::errors::EthTransactionError;
    use super::check_gas_fee;

    #[test]
    fn test_happy_path() {
        let result = check_gas_fee(100, Option::Some(10), 50);
        assert!(result.is_ok());
    }

    #[test]
    fn test_fee_cap_too_low() {
        let result = check_gas_fee(40, Option::Some(10), 50);
        assert_eq!(result, Result::Err(EthTransactionError::FeeCapTooLow));
    }

    #[test]
    fn test_tip_above_fee_cap() {
        let result = check_gas_fee(100, Option::Some(110), 50);
        assert_eq!(result, Result::Err(EthTransactionError::TipAboveFeeCap));
    }

    #[test]
    fn test_priority_fee_none() {
        let result = check_gas_fee(100, Option::None, 50);
        assert!(result.is_ok());
    }
}
