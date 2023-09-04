// SPDX-License-Identifier: MIT

%lang starknet

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

@event
func evm_contract_deployed(evm_contract_address: felt, starknet_contract_address: felt) {
}

@storage_var
func evm_to_starknet_address(evm_address: felt) -> (starknet_address: felt) {
}

namespace Accounts {
    // @dev Returns the registered starknet address for a given EVM address. Returns 0 if no contract is deployed for this
    //      EVM address.
    // @param evm_address The EVM address to transform to a starknet address
    // @return starknet_address The Starknet Account Contract address or 0 if not already deployed
    func get_starknet_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (starknet_address: felt) {
        return evm_to_starknet_address.read(evm_address);
    }

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
        let (starknet_address) = deploy_syscall(
            _account_proxy_class_hash,
            contract_address_salt=evm_address,
            constructor_calldata_size=0,
            constructor_calldata=constructor_calldata,
            deploy_from_zero=0,
        );
        assert constructor_calldata[0] = kakarot_address;
        assert constructor_calldata[1] = evm_address;
        IAccount.initialize(starknet_address, class_hash, 2, constructor_calldata);
        evm_contract_deployed.emit(evm_address, starknet_address);
        evm_to_starknet_address.write(evm_address, starknet_address);
        return (account_address=starknet_address);
    }

    // @notice Returns the bytecode of a given EVM address
    // @dev Returns an empty bytecode if the corresponding Starknet contract is not deployed
    //      as would eth_getCode do to any address
    func get_bytecode{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (bytecode_len: felt, bytecode: felt*) {
        let (starknet_address) = get_starknet_address(evm_address);

        if (starknet_address == 0) {
            let (bytecode: felt*) = alloc();
            return (0, bytecode);
        }

        let (bytecode_len, bytecode) = IAccount.bytecode(contract_address=starknet_address);
        return (bytecode_len, bytecode);
    }

    // @notice Returns the bytecode_len of a given EVM address
    // @dev Returns 0 if the corresponding Starknet contract is not deployed
    //      as would eth_getCode do to any address
    func get_bytecode_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        evm_address: felt
    ) -> (bytecode_len: felt) {
        let (starknet_address) = get_starknet_address(evm_address);

        if (starknet_address == 0) {
            return (bytecode_len=0);
        }

        let (bytecode_len) = IAccount.bytecode_len(contract_address=starknet_address);
        return (bytecode_len=bytecode_len);
    }
}
