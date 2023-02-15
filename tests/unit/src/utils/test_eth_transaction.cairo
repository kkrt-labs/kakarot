%lang starknet

from utils.eth_transaction import EthTransaction
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

@view
func test__decode{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(tx_data_len: felt, tx_data: felt*) -> (
    gas_limit: felt,
    destination: felt,
    amount: felt,
    payload_len: felt,
    payload: felt*,
    tx_hash: Uint256,
    v: felt,
    r: Uint256,
    s: Uint256,
) {
    return EthTransaction.decode(tx_data_len, tx_data);
}

@view
func test__validate{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, bitwise_ptr: BitwiseBuiltin*, range_check_ptr
}(address: felt, tx_data_len: felt, tx_data: felt*) {
    return EthTransaction.validate(address, tx_data_len, tx_data);
}
