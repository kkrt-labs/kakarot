%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IResgistry {
    func get_starknet_address(evm_address: felt) -> (starknet_address: felt) {
    }

    func get_evm_address(starknet_address: felt) -> (evm_address: felt) {
    }
}

@contract_interface
namespace IEth {
    func balanceOf(account: felt) -> (balance: Uint256) {
    }
}
