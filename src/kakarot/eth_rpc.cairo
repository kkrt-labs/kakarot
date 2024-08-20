%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from kakarot.account import Account
from kakarot.storages import Kakarot_native_token_address
from kakarot.interfaces.interfaces import IAccount, IERC20
from utils.utils import Helpers

// @notice The eth_getBalance function as described in the spec
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance
//         This is a view only function, meaning that it doesn't make any state change.
// @param evm_address The address to get the balance from
// @return balance Balance of the address
@view
func eth_get_balance_of{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (balance: Uint256) {
    let starknet_address = Account.get_starknet_address(evm_address);
    let (native_token_address) = Kakarot_native_token_address.read();
    let (balance) = IERC20.balanceOf(native_token_address, starknet_address);
    return (balance=balance);
}

// @notice The eth_getTransactionCount function as described in the spec
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount
//         This is a view only function, meaning that it doesn't make any state change.
// @param evm_address The address to get the transaction count from
// @return Transaction count of the address
@view
func eth_get_transaction_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    evm_address: felt
) -> (tx_count: felt) {
    let starknet_address = Account.get_starknet_address(evm_address);
    let (tx_count) = IAccount.get_nonce(contract_address=starknet_address);
    return (tx_count=tx_count);
}
