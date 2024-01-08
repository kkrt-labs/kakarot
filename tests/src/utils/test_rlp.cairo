%lang starknet

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

@view
func test__decode_at_index{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(data_len: felt, data: felt*, index: felt) -> (data_len: felt, data: felt*, is_list: felt) {
    alloc_locals;
    let (local items: RLP.Item*) = alloc();
    RLP.decode(data_len, data, items);
    let item = items[index];
    return (data_len=item.data_len, data=item.data, is_list=item.is_list);
}
