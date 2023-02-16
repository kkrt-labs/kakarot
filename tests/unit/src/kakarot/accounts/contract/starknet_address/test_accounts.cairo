// SPDX-License-Identifier: MIT

%lang starknet


from kakarot.accounts.library import Accounts


@external
func test__compute_starknet_address{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(evm_address: felt) -> (starknet_contract_address: felt) {
    return Accounts.compute_starknet_address(evm_address);
}
