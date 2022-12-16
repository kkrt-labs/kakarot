%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IRegistry {
    func get_starknet_contract_address(evm_contract_address: felt) -> (
        starknet_contract_address: felt
    ) {
    }

    func get_evm_contract_address(starknet_contract_address: felt) -> (evm_contract_address: felt) {
    }

    func set_account_entry(starknet_contract_address: felt, evm_contract_address: felt) -> () {
    }
}

@contract_interface
namespace IEth {
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
    
    func transfer(recipient: felt, amount: Uint256) -> (success: felt) {
    }
}

@contract_interface
namespace IEvmContract {
    func bytecode_len() -> (len: felt) {
    }
    func bytecode() -> (bytecode_len: felt, bytecode: felt*) {
    }
    func write_bytecode(bytecode_len: felt, bytecode: felt*) {
    }
    func storage(key: Uint256) -> (value: Uint256) {
    }
    func write_storage(key: Uint256, value: Uint256) {
    }
    func initialize(address: felt) {
    }
    func is_initialized() -> (is_initialized: felt) {
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

    func set_account_registry(registry_address_: felt) {
    }

    func get_account_registry() -> (address: felt) {
    }

    func set_native_token(native_token_address_: felt) {
    }

    func deploy(bytecode_len: felt, bytecode: felt*) -> (
        evm_contract_address: felt, starknet_contract_address: felt
    ) {
    }
}
