// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from kakarot.gas import Gas

@external
func test__memory_cost{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    words_len: felt
) -> (cost: felt) {
    let cost = Gas.memory_cost(words_len);
    return (cost=cost);
}
