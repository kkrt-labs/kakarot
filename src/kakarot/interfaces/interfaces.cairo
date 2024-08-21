%lang starknet

from starkware.cairo.common.uint256 import Uint256
from kakarot.model import model
from kakarot.accounts.model import CallArray, OutsideExecution

@contract_interface
namespace IERC20 {
    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
    }

    func name() -> (name: felt) {
    }

    func symbol() -> (symbol: felt) {
    }

    func decimals() -> (decimals: felt) {
    }

    func totalSupply() -> (total_supply: Uint256) {
    }

    func allowance(owner: felt, spender: felt) -> (remaining: Uint256) {
    }
}

@contract_interface
namespace IAccount {
    func get_evm_address() -> (evm_address: felt) {
    }

    func set_implementation(implementation: felt) {
    }

    func bytecode_len() -> (len: felt) {
    }

    func bytecode() -> (bytecode_len: felt, bytecode: felt*) {
    }

    func write_bytecode(bytecode_len: felt, bytecode: felt*) {
    }

    func storage(storage_addr: felt) -> (value: Uint256) {
    }

    func write_storage(storage_addr: felt, value: Uint256) {
    }

    func get_nonce() -> (nonce: felt) {
    }

    func set_nonce(nonce: felt) {
    }

    func is_valid_jumpdest(index: felt) -> (is_valid: felt) {
    }

    func write_jumpdests(jumpdests_len: felt, jumpdests: felt*) {
    }

    func set_authorized_pre_eip155_tx(msg_hash: Uint256) {
    }

    func execute_starknet_call(
        to: felt, function_selector: felt, calldata_len: felt, calldata: felt*
    ) -> (retdata_len: felt, retdata: felt*, success: felt) {
    }

    func get_code_hash() -> (code_hash: Uint256) {
    }

    func set_code_hash(code_hash: Uint256) {
    }

    func execute_from_outside(
        outside_execution: OutsideExecution,
        call_array_len: felt,
        call_array: CallArray*,
        calldata_len: felt,
        calldata: felt*,
        signature_len: felt,
        signature: felt*,
    ) -> (response_len: felt, response: felt*) {
    }
}

@contract_interface
namespace IKakarot {
    func set_native_token(native_token_address: felt) {
    }

    func get_native_token() -> (native_token_address: felt) {
    }

    func set_base_fee(base_fee: felt) {
    }

    func get_base_fee() -> (base_fee: felt) {
    }

    func set_coinbase(coinbase: felt) {
    }

    func get_coinbase() -> (coinbase: felt) {
    }

    func set_block_gas_limit(gas_limit_: felt) {
    }

    func get_block_gas_limit() -> (block_gas_limit: felt) {
    }

    func set_prev_randao(prev_randao: Uint256) {
    }

    func get_prev_randao() -> (prev_randao: Uint256) {
    }

    func deploy_externally_owned_account(evm_address: felt) {
    }

    func compute_starknet_address(evm_address: felt) -> (contract_address: felt) {
    }

    func get_account_contract_class_hash() -> (account_contract_class_hash: felt) {
    }

    func set_account_contract_class_hash(account_contract_class_hash: felt) {
    }

    func get_uninitialized_account_class_hash() -> (uninitialized_account_class_hash: felt) {
    }

    func set_uninitialized_account_class_hash(uninitialized_account_class_hash: felt) {
    }

    func set_cairo1_helpers_class_hash(cairo1_helpers_class_hash: felt) {
    }

    func get_cairo1_helpers_class_hash() -> (cairo1_helpers_class_hash: felt) {
    }

    func register_account(evm_address: felt) {
    }

    func get_starknet_address(evm_address: felt) -> (starknet_address: felt) {
    }

    func eth_call(
        nonce: felt,
        origin: felt,
        to: model.Option,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256,
        data_len: felt,
        data: felt*,
    ) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    }

    func eth_send_transaction(
        to: model.Option,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256,
        data_len: felt,
        data: felt*,
        access_list_len: felt,
        access_list: felt*,
    ) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    }

    func eth_get_balance(address: felt) -> (balance: Uint256) {
    }

    func eth_get_transaction_count(address: felt) -> (tx_count: felt) {
    }

    func eth_chain_id() -> (chain_id: felt) {
    }

    func eth_send_raw_transaction(tx_data_len: felt, tx_data: felt*) -> (
        return_data_len: felt, return_data: felt*, success: felt, gas_used: felt
    ) {
    }
}

@contract_interface
namespace ICairo1Helpers {
    func exec_precompile(address: felt, data_len: felt, data: felt*) -> (
        success: felt, gas: felt, return_data_len: felt, return_data: felt*
    ) {
    }

    func get_block_hash(block_number: felt) -> (hash: felt) {
    }

    func keccak(
        words_len: felt, words: felt*, last_input_word: felt, last_input_num_bytes: felt
    ) -> (hash: Uint256) {
    }

    func recover_eth_address(msg_hash: Uint256, r: Uint256, s: Uint256, y_parity: felt) -> (
        success: felt, address: felt
    ) {
    }

    func verify_signature_secp256r1(
        msg_hash: Uint256, r: Uint256, s: Uint256, x: Uint256, y: Uint256
    ) -> (is_valid: felt) {
    }
}
