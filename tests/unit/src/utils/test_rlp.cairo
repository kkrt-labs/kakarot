%lang starknet

from utils.rlp import RLP
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

@external
func test_encode_rlp_list{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(data_len: felt, data: felt*) -> (data_len: felt, data: felt*) {
    alloc_locals;
    let (local rlp: felt*) = alloc();
    let (rlp_len: felt) = RLP.encode_rlp_list(data_len, data, rlp);
    return (data_len=rlp_len, data=rlp);
}
