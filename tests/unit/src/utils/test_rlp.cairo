%lang starknet

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

@view
<<<<<<< HEAD
func test__encode_list{
=======
func test__encode_rlp_list{
>>>>>>> ce1c8b8528e6b3423923facb3806e08a90723615
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(data_len: felt, data: felt*) -> (data_len: felt, data: felt*) {
    alloc_locals;
    let (local rlp: felt*) = alloc();
<<<<<<< HEAD
    let (rlp_len: felt) = RLP.encode_list(data_len, data, rlp);
=======
    let (rlp_len: felt) = RLP.encode_rlp_list(data_len, data, rlp);
>>>>>>> ce1c8b8528e6b3423923facb3806e08a90723615
    return (data_len=rlp_len, data=rlp);
}

@view
<<<<<<< HEAD
func test__decode_at_index{
=======
func test__rlp_decode_at_index{
>>>>>>> ce1c8b8528e6b3423923facb3806e08a90723615
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(data_len: felt, data: felt*, index: felt) -> (data_len: felt, data: felt*, is_list: felt) {
    alloc_locals;
    let (local items: RLP.Item*) = alloc();
<<<<<<< HEAD
    RLP.decode(data_len, data, items);
=======
    RLP.decode_rlp(data_len, data, items);
>>>>>>> ce1c8b8528e6b3423923facb3806e08a90723615
    let item = items[index];
    return (data_len=item.data_len, data=item.data, is_list=item.is_list);
}
