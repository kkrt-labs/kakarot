%lang starknet

from starkware.cairo.common.uint256 import Uint256
from utils.utils import Option

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

    func initialize(implementation: felt, calldata_len: felt, calldata: felt*) {
    }

    func bytecode_len() -> (len: felt) {
    }

    func bytecode() -> (bytecode_len: felt, bytecode: felt*) {
    }

    func account_type() -> (type: felt) {
    }
}

@contract_interface
namespace IContractAccount {
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

    func selfdestruct() {
    }
}

@contract_interface
namespace IKakarot {
    func set_native_token(native_token_address_: felt) {
    }

    func get_native_token() -> (native_token_address: felt) {
    }

    func set_base_fee(base_fee_: felt) {
    }

    func get_base_fee() -> (base_fee: felt) {
    }

    func set_coinbase(coinbase_: felt) {
    }

    func get_coinbase() -> (coinbase: felt) {
    }

    func deploy_externally_owned_account(evm_address: felt) {
    }

    func compute_starknet_address(evm_address: felt) -> (contract_address: felt) {
    }

    func get_starknet_address(evm_address: felt) -> (starknet_address: felt) {
    }

    func eth_call(
        origin: felt,
        to: Option,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256,
        data_len: felt,
        data: felt*,
    ) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    }

    func eth_send_transaction(
        to: Option,
        gas_limit: felt,
        gas_price: felt,
        value: Uint256,
        data_len: felt,
        data: felt*,
        access_list_len: felt,
        access_list: felt*,
    ) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    }
}

@contract_interface
namespace IPrecompiles {
    func exec_precompile(address: felt, data_len: felt, data: felt*) -> (
        success: felt, gas: felt, return_data_len: felt, return_data: felt*
    ) {
    }
}
