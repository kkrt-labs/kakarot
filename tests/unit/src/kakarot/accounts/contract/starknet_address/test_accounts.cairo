// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from kakarot.accounts.library import Accounts


@external
func test__compute_starknet_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) -> (starknet_address: felt) {
    let (starknet_address_computation) = Accounts.compute_starknet_address(evm_address);
    return (starknet_address=starknet_address_computation);
}
