// SPDX-License-Identifier: MIT

%lang starknet

from openzeppelin.access.ownable.library import Ownable
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import replace_class, get_contract_address
from kakarot.interfaces.interfaces import IERC20

@external
func set_implementation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Ownable.assert_only_owner();
    replace_class(new_implementation);
    return ();
}

@external
func send_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address: felt, recipient: felt
) {
    let (this) = get_contract_address();
    let (balance) = IERC20.balanceOf(token_address, this);
    IERC20.transfer(token_address, recipient, balance);
    return ();
}
