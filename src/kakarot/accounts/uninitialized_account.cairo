// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address, replace_class, library_call

@contract_interface
namespace IKakarot {
    func get_account_contract_class_hash() -> (account_contract_class_hash: felt) {
    }
}

const INITIALIZE_SELECTOR = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;  // sn_keccak('initialize')

// @title Uninitialized Contract Account. Used to get a deterministic address for an account, no
// matter the actual implementation class used.

// @notice Deploys and initializes the account with the Kakarot and EVM addresses it was deployed with.
// @param kakarot_address The address of the main Kakarot contract.
// @param evm_address The address of the EVM contract.
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    kakarot_address: felt, evm_address: felt
) {
    let (implementation_class) = IKakarot.get_account_contract_class_hash(kakarot_address);

    let (calldata) = alloc();
    assert calldata[0] = kakarot_address;
    assert calldata[1] = evm_address;
    assert calldata[2] = implementation_class;

    library_call(
        class_hash=implementation_class,
        function_selector=INITIALIZE_SELECTOR,
        calldata_size=3,
        calldata=calldata,
    );

    replace_class(implementation_class);
    return ();
}
