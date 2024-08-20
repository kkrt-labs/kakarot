%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_tx_info

from kakarot.account import Account
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.storages import Kakarot_native_token_address
from kakarot.library import Kakarot
from utils.maths import unsigned_div_rem
from utils.utils import Helpers

// @notice The eth_getBalance function as described in the spec
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance
//         This is a view only function, meaning that it doesn't make any state change.
// @param address The address to get the balance from
// @return balance Balance of the address
@view
func eth_get_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (balance: Uint256) {
    let starknet_address = Account.get_starknet_address(address);
    let (native_token_address) = Kakarot_native_token_address.read();
    let (balance) = IERC20.balanceOf(native_token_address, starknet_address);
    return (balance=balance);
}

// @notice The eth_getTransactionCount function as described in the spec
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount
//         This is a view only function, meaning that it doesn't make any state change.
// @param address The address to get the transaction count from
// @return Transaction count of the address
@view
func eth_get_transaction_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (tx_count: felt) {
    let starknet_address = Account.get_starknet_address(address);
    let (tx_count) = IAccount.get_nonce(contract_address=starknet_address);
    return (tx_count=tx_count);
}

// @notice The eth_chainId function as described in the spec
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid
//         This is a view only function, meaning that it doesn't make any state change.
// @return Transaction count of the address
@view
func eth_chain_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    chain_id: felt
) {
    let (chain_id) = Kakarot.eth_chain_id();
    return (chain_id=chain_id);
}
