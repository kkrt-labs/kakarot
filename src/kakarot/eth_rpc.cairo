%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_not_zero
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info

from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.storages import Kakarot_native_token_address
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
// @return tx_count Transaction count of the address
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
// @return chain_id Chaind id of the chain
@view
func eth_chain_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    chain_id: felt
) {
    let (chain_id) = Kakarot.eth_chain_id();
    return (chain_id=chain_id);
}

// @notice The eth_call function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
//         This is a view only function, meaning that it doesn't make any state change.
// @param nonce The nonce of the account the transaction is sent from.
// @param origin The address the transaction is sent from.
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @param access_list_len The length of the access list
// @param access_list The access list passed in the transaction
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return gas_used The amount of gas used by the transaction
@view
func eth_call{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    nonce: felt,
    origin: felt,
    to: model.Option,
    gas_limit: felt,
    gas_price: felt,
    value: Uint256,
    data_len: felt,
    data: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    alloc_locals;

    Helpers.assert_view_call();

    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    let (evm, state, gas_used, _) = Kakarot.eth_call(
        nonce,
        origin,
        to,
        gas_limit,
        gas_price,
        &value,
        data_len,
        data,
        access_list_len,
        access_list,
    );
    let is_reverted = is_not_zero(evm.reverted);
    return (evm.return_data_len, evm.return_data, 1 - is_reverted, gas_used);
}

// @notice The eth_estimateGas function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call
//         This is a view only function, meaning that it doesn't make any state change.
// @param nonce The nonce of the account the transaction is sent from.
// @param origin The address the transaction is sent from.
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @param access_list_len The length of the access list
// @param access_list The access list passed in the transaction
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return required_gas The amount of gas required by the transaction to successfully execute. This is different
// from the gas used by the transaction as it doesn't take into account any refunds.
@view
func eth_estimate_gas{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    nonce: felt,
    origin: felt,
    to: model.Option,
    gas_limit: felt,
    gas_price: felt,
    value: Uint256,
    data_len: felt,
    data: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt, required_gas: felt) {
    alloc_locals;

    Helpers.assert_view_call();

    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    let (evm, state, _, gas_required) = Kakarot.eth_call(
        nonce,
        origin,
        to,
        gas_limit,
        gas_price,
        &value,
        data_len,
        data,
        access_list_len,
        access_list,
    );
    let is_reverted = is_not_zero(evm.reverted);
    return (evm.return_data_len, evm.return_data, 1 - is_reverted, gas_required);
}

// @notice The eth_send_transaction function as described in the spec,
//         see https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction
// @dev "nonce" parameter is taken from the corresponding account contract
// @param to The address the transaction is directed to.
// @param gas_limit Integer of the gas provided for the transaction execution
// @param gas_price Integer of the gas price used for each paid gas
// @param value Integer of the value sent with this transaction
// @param data_len The length of the data
// @param data Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI in the Solidity documentation
// @param access_list_len The length of the access list
// @param access_list The access list passed in the transaction
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return gas_used The amount of gas used by the transaction
@external
func eth_send_transaction{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(
    to: model.Option,
    gas_limit: felt,
    gas_price: felt,
    value: Uint256,
    data_len: felt,
    data: felt*,
    access_list_len: felt,
    access_list: felt*,
) -> (return_data_len: felt, return_data: felt*, success: felt, gas_used: felt) {
    alloc_locals;
    let fp_and_pc = get_fp_and_pc();
    local __fp__: felt* = fp_and_pc.fp_val;
    let (local starknet_caller_address) = get_caller_address();
    let (local origin) = Kakarot.safe_get_evm_address(starknet_caller_address);
    let (local nonce) = IAccount.get_nonce(starknet_caller_address);

    let (evm, state, gas_used, _) = Kakarot.eth_call(
        nonce,
        origin,
        to,
        gas_limit,
        gas_price,
        &value,
        data_len,
        data,
        access_list_len,
        access_list,
    );

    // Reverted or not - commit the state change. If reverted, the state was cleared to only contain gas-related changes.
    Starknet.commit(state);

    let is_reverted = is_not_zero(evm.reverted);
    let result = (evm.return_data_len, evm.return_data, 1 - is_reverted, gas_used);

    return result;
}
