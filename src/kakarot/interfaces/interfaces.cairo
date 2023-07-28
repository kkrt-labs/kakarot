%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IBlockhashRegistry {
    func set_blockhashes(
        block_number_len: felt, block_number: Uint256*, block_hash_len: felt, block_hash: felt*
    ) -> () {
    }

    func get_blockhash(block_number: Uint256) -> (blockhash: felt) {
    }
}

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
}

@contract_interface
namespace IContractAccount {
    func write_bytecode(bytecode_len: felt, bytecode: felt*) {
    }

    func storage(key: Uint256) -> (value: Uint256) {
    }

    func write_storage(key: Uint256, value: Uint256) {
    }
}

@contract_interface
namespace IKakarot {
    func set_blockhash_registry(blockhash_registry_address_: felt) -> () {
    }

    func get_blockhash_registry() -> (address: felt) {
    }

    func set_native_token(native_token_address_: felt) {
    }

    func get_native_token() -> (native_token_address: felt) {
    }

    func deploy_externally_owned_account(evm_address: felt) {
    }

    func compute_starknet_address(evm_address: felt) -> (contract_address: felt) {
    }

    func eth_call(
        to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*
    ) -> (return_data_len: felt, return_data: felt*) {
    }

    func eth_send_transaction(
        to: felt, gas_limit: felt, gas_price: felt, value: felt, data_len: felt, data: felt*
    ) -> (return_data_len: felt, return_data: felt*) {
    }
}
