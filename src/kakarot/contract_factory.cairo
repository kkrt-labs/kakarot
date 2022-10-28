// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy

// Local dependencies

@storage_var
func salt() -> (value: felt) {
}

@storage_var
func EVM_contract_class_hash() -> (value: felt) {
}

@storage_var
func evm_address_to_starknet_address(evm_contract_address: felt) -> (starknet_address: felt) {
}

namespace EvmContractFactory {
    // Store the EVM contract hash
    func init{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        class_hash: felt
    ) -> () {
        EVM_contract_class_hash.write(class_hash);
        return ();
    }

    @external
    func deploy_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        bytes_len: felt, bytes: felt*
    ) -> felt {
        alloc_locals;
        let (current_salt) = salt.read();
        let (class_hash) = EVM_contract_class_hash.read();

        let (local calldata: felt*) = alloc();
        assert [calldata] = bytes_len;
        memcpy(dst=calldata + 1, src=bytes, len=bytes_len);

        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=bytes_len + 1,
            constructor_calldata=calldata,
            deploy_from_zero=FALSE,
        );
        salt.write(value=current_salt + 1);
        // Generate EVM_contract address from the new cairo contract
        // let (evm_contract_address,_) = unsigned_div_rem(contract_address, 1000000000000000000000000000000000000000000000000);
        let evm_contract_address = 123;
        evm_address_to_starknet_address.write(evm_contract_address, contract_address);
        return (evm_contract_address);
    }
}
