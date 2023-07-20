// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import FALSE
from starkware.starknet.common.syscalls import deploy as deploy_syscall
from starkware.starknet.common.syscalls import get_contract_address
from starkware.starknet.common.storage import normalize_address
from starkware.cairo.common.hash_state import (
    hash_finalize,
    hash_init,
    hash_update,
    hash_update_single,
    hash_update_with_hashchain,
)

from kakarot.constants import Constants, account_proxy_class_hash
from kakarot.interfaces.interfaces import IAccount

@storage_var
func nonce() -> (nonce: felt) {
}

@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

namespace Accounts {
    // @dev As contract addresses are deterministic we can know what will be the address of a starknet contract from its input EVM address
    // @dev Adapted code from: https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/core/os/contract_address/contract_address.cairo
    // @param evm_address The EVM address to transform to a starknet address
    // @return contract_address The Starknet Account Contract address (not necessarily deployed)
    func compute_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (contract_address: felt) {
        alloc_locals;
        let (_deployer_address: felt) = get_contract_address();
        let (_account_proxy_class_hash: felt) = account_proxy_class_hash.read();
        let (constructor_calldata: felt*) = alloc();
        let (hash_state_ptr) = hash_init();
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=Constants.CONTRACT_ADDRESS_PREFIX
        );
        // hash deployer
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=_deployer_address
        );
        // hash salt
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=evm_address
        );
        // hash class hash
        let (hash_state_ptr) = hash_update_single{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, item=_account_proxy_class_hash
        );
        let (hash_state_ptr) = hash_update_with_hashchain{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr, data_ptr=constructor_calldata, data_length=0
        );
        let (contract_address_before_modulo) = hash_finalize{hash_ptr=pedersen_ptr}(
            hash_state_ptr=hash_state_ptr
        );
        let (contract_address) = normalize_address{range_check_ptr=range_check_ptr}(
            addr=contract_address_before_modulo
        );

        return (contract_address=contract_address);
    }

    // @notice Deploy a new account proxy
    // @dev Deploy an instance of an account
    // @param evm_address The Ethereum address which will be controlling the account
    // @param class_hash The hash of the implemented account (eoa/contract)
    // @return account_address The Starknet Account Proxy address
    func create{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_hash: felt, evm_address: felt
    ) -> (account_address: felt) {
        alloc_locals;
        let (kakarot_address: felt) = get_contract_address();
        let (_account_proxy_class_hash: felt) = account_proxy_class_hash.read();
        let (constructor_calldata: felt*) = alloc();
        let (account_address) = deploy_syscall(
            _account_proxy_class_hash,
            contract_address_salt=evm_address,
            constructor_calldata_size=0,
            constructor_calldata=constructor_calldata,
            deploy_from_zero=0,
        );
        assert constructor_calldata[0] = kakarot_address;
        assert constructor_calldata[1] = evm_address;
        IAccount.initialize(account_address, class_hash, 2, constructor_calldata);
        evm_contract_deployed.emit(evm_address, account_address);

        return (account_address=account_address);
    }

    // @notice This function increases the accounts nonce by 1
    // @return nonce: The incremented nonce of the contract account
    func increment_nonce{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        nonce: felt
    ) {
        let (current_nonce: felt) = nonce.read();
        nonce.write(current_nonce + 1);
        return (nonce=current_nonce + 1);
    }
}
