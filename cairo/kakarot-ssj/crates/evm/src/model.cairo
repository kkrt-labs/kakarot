pub mod account;
pub mod vm;
pub use account::{Account, AccountTrait};
pub use vm::{VM, VMTrait};
use contracts::kakarot_core::{KakarotCore, IKakarotCore};
use core::num::traits::{CheckedSub, Zero};
use core::starknet::{EthAddress, ContractAddress};
use crate::errors::EVMError;
use crate::precompiles::{
    FIRST_ROLLUP_PRECOMPILE_ADDRESS, FIRST_ETHEREUM_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS
};
use crate::state::State;
use utils::fmt::{TSpanSetDebug};
use utils::set::SpanSet;
use utils::traits::{EthAddressDefault, ContractAddressDefault, SpanDefault};

/// Represents the execution environment for EVM transactions.
#[derive(Destruct, Default)]
pub struct Environment {
    /// The origin address of the transaction.
    pub origin: Address,
    /// The gas price for the transaction.
    pub gas_price: u128,
    /// The chain ID of the network.
    pub chain_id: u64,
    /// The previous RANDAO value.
    pub prevrandao: u256,
    /// The current block number.
    pub block_number: u64,
    /// The gas limit for the current block.
    pub block_gas_limit: u64,
    /// The timestamp of the current block.
    pub block_timestamp: u64,
    /// The address of the coinbase.
    pub coinbase: EthAddress,
    /// The base fee for the current block.
    pub base_fee: u64,
    /// The state of the EVM.
    pub state: State
}

/// Represents a message call in the EVM.
#[derive(Copy, Drop, Default, PartialEq, Debug)]
pub struct Message {
    /// The address of the caller.
    pub caller: Address,
    /// The target address of the call.
    pub target: Address,
    /// The gas limit for the call.
    pub gas_limit: u64,
    /// The data passed to the call.
    pub data: Span<u8>,
    /// The code of the contract being called.
    pub code: Span<u8>,
    /// The address of the code being executed.
    pub code_address: Address,
    /// The value sent with the call.
    pub value: u256,
    /// Whether the value should be transferred.
    pub should_transfer_value: bool,
    /// The depth of the call stack.
    pub depth: usize,
    /// Whether the call is read-only.
    pub read_only: bool,
    /// Set of accessed addresses during execution.
    pub accessed_addresses: SpanSet<EthAddress>,
    /// Set of accessed storage keys during execution.
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
}

/// Represents the result of an EVM execution.
#[derive(Drop, Debug)]
pub struct ExecutionResult {
    /// The status of the execution result.
    pub status: ExecutionResultStatus,
    /// The return data of the execution.
    pub return_data: Span<u8>,
    /// The remaining gas after execution.
    pub gas_left: u64,
    /// Set of accessed addresses during execution.
    pub accessed_addresses: SpanSet<EthAddress>,
    /// Set of accessed storage keys during execution.
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    /// The amount of gas refunded during execution.
    pub gas_refund: u64,
}

/// Represents the status of an EVM execution result.
#[derive(Copy, Drop, PartialEq, Debug)]
pub enum ExecutionResultStatus {
    /// The execution was successful.
    Success,
    /// The execution was reverted.
    Revert,
    /// An exception occurred during execution.
    Exception,
}

#[generate_trait]
pub impl ExecutionResultImpl of ExecutionResultTrait {
    /// Creates an `ExecutionResult` for an exceptional failure.
    ///
    /// # Arguments
    ///
    /// * `error` - The error message as a span of bytes.
    /// * `accessed_addresses` - Set of accessed addresses during execution.
    /// * `accessed_storage_keys` - Set of accessed storage keys during execution.
    ///
    /// # Returns
    ///
    /// An `ExecutionResult` with the Exception status and provided data.
    fn exceptional_failure(
        error: Span<u8>,
        accessed_addresses: SpanSet<EthAddress>,
        accessed_storage_keys: SpanSet<(EthAddress, u256)>
    ) -> ExecutionResult {
        ExecutionResult {
            status: ExecutionResultStatus::Exception,
            return_data: error,
            gas_left: 0,
            accessed_addresses,
            accessed_storage_keys,
            gas_refund: 0,
        }
    }

    /// Decrements the gas_left field of the current execution context by the value amount.
    ///
    /// # Arguments
    ///
    /// * `value` - The amount of gas to charge.
    ///
    /// # Returns
    ///
    /// `Ok(())` if successful, or `Err(EVMError::OutOfGas)` if there's not enough gas.
    #[inline(always)]
    fn charge_gas(ref self: ExecutionResult, value: u64) -> Result<(), EVMError> {
        self.gas_left = self.gas_left.checked_sub(value).ok_or(EVMError::OutOfGas)?;
        Result::Ok(())
    }

    /// Checks if the execution result status is Success.
    ///
    /// # Returns
    ///
    /// `true` if the status is Success, `false` otherwise.
    fn is_success(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Success
    }

    /// Checks if the execution result status is Exception.
    ///
    /// # Returns
    ///
    /// `true` if the status is Exception, `false` otherwise.
    fn is_exception(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Exception
    }

    /// Checks if the execution result status is Revert.
    ///
    /// # Returns
    ///
    /// `true` if the status is Revert, `false` otherwise.
    fn is_revert(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Revert
    }
}

/// Represents a summary of an EVM execution.
#[derive(Destruct)]
pub struct ExecutionSummary {
    /// The status of the execution result.
    pub status: ExecutionResultStatus,
    /// The return data of the execution.
    pub return_data: Span<u8>,
    /// The remaining gas after execution.
    pub gas_left: u64,
    /// The state of the EVM after execution.
    pub state: State,
    /// The amount of gas refunded during execution.
    pub gas_refund: u64
}

/// Represents the result of an EVM transaction.
pub struct TransactionResult {
    /// Whether the transaction was successful.
    pub success: bool,
    /// The return data of the transaction.
    pub return_data: Span<u8>,
    /// The amount of gas used by the transaction.
    pub gas_used: u64,
    /// The state of the EVM after the transaction.
    pub state: State
}

#[generate_trait]
pub impl TransactionResultImpl of TransactionResultTrait {
    /// Creates a `TransactionResult` for an exceptional failure.
    ///
    /// # Arguments
    ///
    /// * `error` - The error message as a span of bytes.
    /// * `gas_used` - The amount of gas used during the transaction.
    ///
    /// # Returns
    ///
    /// A `TransactionResult` with failure status and provided data.
    fn exceptional_failure(error: Span<u8>, gas_used: u64) -> TransactionResult {
        TransactionResult {
            success: false, return_data: error, gas_used, state: Default::default()
        }
    }
}

/// Represents an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
pub struct Event {
    /// The keys of the event.
    pub keys: Array<u256>,
    /// The data of the event.
    pub data: Array<u8>,
}

/// Represents an address in both EVM and Starknet formats.
#[derive(Copy, Drop, PartialEq, Default, Debug)]
pub struct Address {
    /// The EVM address.
    pub evm: EthAddress,
    /// The Starknet address.
    pub starknet: ContractAddress,
}

impl ZeroAddress of core::num::traits::Zero<Address> {
    fn zero() -> Address {
        Address { evm: Zero::zero(), starknet: Zero::zero(), }
    }
    fn is_zero(self: @Address) -> bool {
        self.evm.is_zero() && self.starknet.is_zero()
    }
    fn is_non_zero(self: @Address) -> bool {
        !self.is_zero()
    }
}

#[generate_trait]
pub impl AddressImpl of AddressTrait {
    /// Checks if the EVM address is deployed.
    ///
    /// # Returns
    ///
    /// `true` if the address is deployed, `false` otherwise.
    fn is_deployed(self: @EthAddress) -> bool {
        let mut kakarot_state = KakarotCore::unsafe_new_contract_state();
        let address = kakarot_state.address_registry(*self);
        return address.is_non_zero();
    }

    /// Checks if the address is a precompile for a call-family opcode.
    ///
    /// # Returns
    ///
    /// `true` if the address is a precompile, `false` otherwise.
    fn is_precompile(self: EthAddress) -> bool {
        let self: felt252 = self.into();
        return self != 0x00
            && (FIRST_ETHEREUM_PRECOMPILE_ADDRESS <= self.into()
                && self.into() <= LAST_ETHEREUM_PRECOMPILE_ADDRESS)
                || self.into() == FIRST_ROLLUP_PRECOMPILE_ADDRESS;
    }
}

/// Represents a native token transfer to be made when finalizing a transaction.
#[derive(Copy, Drop, PartialEq, Debug)]
pub struct Transfer {
    /// The sender of the transfer.
    pub sender: Address,
    /// The recipient of the transfer.
    pub recipient: Address,
    /// The amount of tokens to transfer.
    pub amount: u256
}

#[cfg(test)]
mod tests {
    mod test_is_deployed {
        use crate::model::AddressTrait;
        use crate::test_utils;
        use snforge_std::test_address;
        use utils::helpers::compute_starknet_address;


        #[test]
        fn test_is_deployed_returns_true_if_in_registry() {
            // Given
            test_utils::setup_test_environment();
            let starknet_address = compute_starknet_address(
                test_address(), test_utils::evm_address(), test_utils::uninitialized_account()
            );
            test_utils::register_account(test_utils::evm_address(), starknet_address);

            // When
            let is_deployed = test_utils::evm_address().is_deployed();

            // Then
            assert!(is_deployed);
        }

        #[test]
        fn test_is_deployed_undeployed() {
            // Given
            test_utils::setup_test_environment();

            // When
            let is_deployed = test_utils::evm_address().is_deployed();

            // Then
            assert!(!is_deployed);
        }
    }
    mod test_is_precompile {
        use core::starknet::EthAddress;
        use crate::model::{AddressTrait};
        #[test]
        fn test_is_precompile() {
            // Given
            let valid_precompiles = array![
                0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x0a, 0x100
            ];

            //When
            for el in valid_precompiles {
                let evm_address: EthAddress = (el).try_into().unwrap();
                //Then
                assert_eq!(true, evm_address.is_precompile());
            };
        }

        #[test]
        fn test_is_precompile_zero() {
            // Given
            let evm_address: EthAddress = 0x0.try_into().unwrap();

            // When
            let is_precompile = evm_address.is_precompile();

            // Then
            assert_eq!(false, is_precompile);
        }

        #[test]
        fn test_is_not_precompile() {
            // Given
            let not_valid_precompiles = array![0xb, 0xc, 0xd, 0xe, 0xf, 0x99];

            //When
            for el in not_valid_precompiles {
                let evm_address: EthAddress = (el).try_into().unwrap();
                //Then
                assert_eq!(false, evm_address.is_precompile());
            };
        }
    }
}
