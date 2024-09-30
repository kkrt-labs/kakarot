use core::num::traits::Zero;
use core::starknet::get_tx_info;
use core::starknet::{EthAddress, get_caller_address};
use crate::account_contract::{IAccountDispatcher, IAccountDispatcherTrait};
use crate::kakarot_core::interface::IKakarotCore;
use crate::kakarot_core::kakarot::{KakarotCore, KakarotCore::{KakarotCoreState}};
use evm::backend::starknet_backend;
use evm::backend::validation::validate_eth_tx;
use evm::model::{TransactionResult, Address};
use evm::{EVMTrait};
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use utils::constants::POW_2_53;
use utils::eth_transaction::transaction::Transaction;

#[starknet::interface]
pub trait IEthRPC<T> {
    /// Returns the balance of the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the balance from
    ///
    /// # Returns
    ///
    /// The balance of the address as a u256
    fn eth_get_balance(self: @T, address: EthAddress) -> u256;

    /// Returns the number of transactions sent from the specified address.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `address` - The Ethereum address to get the transaction count from
    ///
    /// # Returns
    ///
    /// The transaction count of the address as a u64
    fn eth_get_transaction_count(self: @T, address: EthAddress) -> u64;

    /// Returns the current chain ID.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Returns
    ///
    /// The chain ID as a u64
    fn eth_chain_id(self: @T) -> u64;

    /// Executes a new message call immediately without creating a transaction on the block chain.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_call(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);

    /// Generates and returns an estimate of how much gas is necessary to allow the transaction to
    /// complete.
    ///
    /// This is a view-only function that doesn't modify the state.
    ///
    /// # Arguments
    ///
    /// * `origin` - The address the transaction is sent from
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The estimated gas as a u64
    fn eth_estimate_gas(self: @T, origin: EthAddress, tx: Transaction) -> (bool, Span<u8>, u64);

    //TODO: make this an internal function. The account contract should call
    //eth_send_raw_transaction.
    /// Executes a transaction and possibly modifies the state.
    ///
    /// # Arguments
    ///
    /// * `tx` - The transaction object
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_send_transaction(ref self: T, tx: Transaction) -> (bool, Span<u8>, u64);

    /// Executes an unsigned transaction.
    ///
    /// This is a modified version of the eth_sendRawTransaction function.
    /// Signature validation should be done before calling this function.
    ///
    /// # Arguments
    ///
    /// * `tx_data` - The unsigned transaction data as a Span<u8>
    ///
    /// # Returns
    ///
    /// A tuple containing:
    /// * A boolean indicating success
    /// * The return data as a Span<u8>
    /// * The amount of gas used as a u64
    fn eth_send_raw_unsigned_tx(ref self: T, tx_data: Span<u8>) -> (bool, Span<u8>, u64);
}


#[starknet::embeddable]
pub impl EthRPC<
    TContractState, impl KakarotState: KakarotCoreState<TContractState>, +Drop<TContractState>
> of IEthRPC<TContractState> {
    fn eth_get_balance(self: @TContractState, address: EthAddress) -> u256 {
        let kakarot_state = KakarotState::get_state();
        let starknet_address = kakarot_state.get_starknet_address(address);
        let native_token_address = kakarot_state.get_native_token();
        let native_token = IERC20CamelDispatcher { contract_address: native_token_address };
        native_token.balanceOf(starknet_address)
    }

    fn eth_get_transaction_count(self: @TContractState, address: EthAddress) -> u64 {
        let kakarot_state = KakarotState::get_state();
        let starknet_address = kakarot_state.get_starknet_address(address);
        println!("starknet_address: {:?}", starknet_address);
        let account = IAccountDispatcher { contract_address: starknet_address };
        let nonce = account.get_nonce();
        nonce
    }

    fn eth_chain_id(self: @TContractState) -> u64 {
        let tx_info = get_tx_info().unbox();
        let tx_chain_id: u64 = tx_info.chain_id.try_into().unwrap();
        tx_chain_id % POW_2_53.try_into().unwrap()
    }

    fn eth_call(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        if !is_view(@kakarot_state) {
            core::panic_with_felt252('fn must be called, not invoked');
        };

        let origin = Address {
            evm: origin, starknet: kakarot_state.compute_starknet_address(origin)
        };

        let TransactionResult { success, return_data, gas_used, state: _state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, 0
        );

        (success, return_data, gas_used)
    }

    fn eth_estimate_gas(
        self: @TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }

    //TODO: make this one internal, and the eth_send_raw_unsigned_tx one public
    fn eth_send_transaction(
        ref self: TContractState, mut tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        let mut kakarot_state = KakarotState::get_state();
        let intrinsic_gas = validate_eth_tx(@kakarot_state, tx);

        let starknet_caller_address = get_caller_address();
        let account = IAccountDispatcher { contract_address: starknet_caller_address };
        let origin = Address { evm: account.get_evm_address(), starknet: starknet_caller_address };

        let TransactionResult { success, return_data, gas_used, mut state } =
            EVMTrait::process_transaction(
            ref kakarot_state, origin, tx, intrinsic_gas
        );
        starknet_backend::commit(ref state).expect('Committing state failed');
        (success, return_data, gas_used)
    }

    fn eth_send_raw_unsigned_tx(
        ref self: TContractState, tx_data: Span<u8>
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }
}

trait IEthRPCInternal<T> {
    fn eth_send_transaction(
        ref self: T, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64);
}

impl EthRPCInternalImpl<TContractState, +Drop<TContractState>> of IEthRPCInternal<TContractState> {
    fn eth_send_transaction(
        ref self: TContractState, origin: EthAddress, tx: Transaction
    ) -> (bool, Span<u8>, u64) {
        panic!("unimplemented")
    }
}

fn is_view(self: @KakarotCore::ContractState) -> bool {
    let tx_info = get_tx_info().unbox();

    // If the account that originated the transaction is not zero, this means we
    // are in an invoke transaction instead of a call; therefore, `eth_call` is being
    // wrongly called For invoke transactions, `eth_send_transaction` must be used
    if !tx_info.account_contract_address.is_zero() {
        return false;
    }
    true
}

#[cfg(test)]
mod tests {
    use crate::kakarot_core::KakarotCore;
    use crate::kakarot_core::eth_rpc::IEthRPC;
    use crate::kakarot_core::interface::IExtendedKakarotCoreDispatcherTrait;
    use crate::test_utils::{setup_contracts_for_testing, fund_account_with_native_token};
    use evm::test_utils::{sequencer_evm_address, evm_address, uninitialized_account};
    use snforge_std::{
        start_mock_call, start_cheat_chain_id_global, stop_cheat_chain_id_global, test_address
    };
    use utils::constants::POW_2_53;
    use utils::helpers::compute_starknet_address;

    fn set_up() -> KakarotCore::ContractState {
        // Define the kakarot state to access contract functions
        let kakarot_state = KakarotCore::unsafe_new_contract_state();

        kakarot_state
    }

    fn tear_down() {
        stop_cheat_chain_id_global();
    }

    #[test]
    fn test_eth_get_transaction_count() {
        let kakarot_state = set_up();
        // Deployed eoa should return a zero nonce
        let starknet_address = compute_starknet_address(
            test_address(),
            evm_address(),
            0.try_into().unwrap() // Using 0 as the kakarot storage is empty
        );
        start_mock_call::<u256>(starknet_address, selector!("get_nonce"), 1);
        assert_eq!(kakarot_state.eth_get_transaction_count(evm_address()), 1);
    }

    #[test]
    fn test_eth_get_balance() {
        let (native_token, kakarot_core) = setup_contracts_for_testing();
        // Uninitialized accounts should return a zero balance
        assert_eq!(kakarot_core.eth_get_balance(evm_address()), 0);
        let sequencer_starknet_address = kakarot_core.get_starknet_address(sequencer_evm_address());
        // Fund an initialized account and make sure the balance is correct
        fund_account_with_native_token(sequencer_starknet_address, native_token, 0x1);
        assert_eq!(kakarot_core.eth_get_balance(sequencer_evm_address()), 0x1);
    }

    #[test]
    fn test_eth_chain_id_returns_input_when_less_than_pow_2_53() {
        let kakarot_state = KakarotCore::unsafe_new_contract_state();
        // Convert POW_2_53 - 1 to u64 since POW_2_53 is defined as u128
        let chain_id: u64 = (POW_2_53 - 1).try_into().unwrap();
        start_cheat_chain_id_global(chain_id.into());
        assert_eq!(
            kakarot_state.eth_chain_id(),
            chain_id,
            "Should return original chain ID when below 2^53"
        );
        tear_down();
    }

    #[test]
    fn test_eth_chain_id_returns_modulo_when_greater_than_or_equal_to_pow_2_53() {
        // Test with a value equal to 2^53
        let kakarot_state = set_up();
        let chain_id: u64 = POW_2_53.try_into().unwrap();
        start_cheat_chain_id_global(chain_id.into());
        assert_eq!(kakarot_state.eth_chain_id(), 0, "Should return 0 when chain ID is 2^53");

        // Test with a value greater than 2^53
        let chain_id: u64 = (POW_2_53 + 53).try_into().unwrap();
        start_cheat_chain_id_global(chain_id.into());
        assert_eq!(
            kakarot_state.eth_chain_id(), 53, "Should return correct value after modulo operation"
        );
        tear_down();
    }
}
