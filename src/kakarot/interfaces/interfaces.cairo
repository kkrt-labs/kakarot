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
namespace IEth {
    func balanceOf(account: felt) -> (balance: Uint256) {
    }

    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }

    func approve(spender: felt, amount: Uint256) -> (success: felt) {
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

    func get_nonce() -> (nonce: felt) {
    }

    func increment_nonce() {
    }
}

@contract_interface
namespace IKakarot {
    func execute(
        value: felt, bytecode_len: felt, bytecode: felt*, calldata_len: felt, calldata: felt*
    ) {
    }

    func execute_at_address(
        address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*
    ) {
    }

    func set_blockhash_registry(blockhash_registry_address_: felt) -> () {
    }

    func get_blockhash_registry() -> (address: felt) {
    }

    func set_native_token(native_token_address_: felt) {
    }

    func get_native_token() -> (native_token_address: felt) {
    }

    func deploy(bytecode_len: felt, bytecode: felt*) -> (
        evm_contract_address: felt, starknet_contract_address: felt
    ) {
    }
}
