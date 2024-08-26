%lang starknet

from openzeppelin.access.ownable.library import Ownable_owner
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_le, assert_nn, split_felt
from starkware.cairo.common.math_cmp import is_not_zero, is_nn
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_le
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info

from backend.starknet import Starknet
from kakarot.account import Account
from kakarot.interfaces.interfaces import IAccount, IERC20
from kakarot.library import Kakarot
from kakarot.model import model
from kakarot.storages import Kakarot_native_token_address
from utils.eth_transaction import EthTransaction
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

// @notice The eth_send_raw_unsigned_tx. Modified version of eth_sendRawTransaction function described in the spec.
//         See https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendrawtransaction
// @dev This function takes the transaction data unsigned. Signature validation should be done before calling this function.
// @param tx_data_len The length of the unsigned transaction data
// @param tx_data The unsigned transaction data
// @return return_data_len The length of the return_data
// @return return_data An array of returned felts
// @return success An boolean, TRUE if the transaction succeeded, FALSE otherwise
// @return gas_used The amount of gas used by the transaction
@external
func eth_send_raw_unsigned_tx{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(tx_data_len: felt, tx_data: felt*) -> (
    return_data_len: felt, return_data: felt*, success: felt, gas_used: felt
) {
    alloc_locals;
    let tx = EthTransaction.decode(tx_data_len, tx_data);

    // Validate chain_id for post eip155
    let (chain_id) = Kakarot.eth_chain_id();
    if (tx.chain_id.is_some != FALSE) {
        with_attr error_message("Invalid chain id") {
            assert tx.chain_id.value = chain_id;
        }
    }

    // Get the caller address
    let (caller_address) = get_caller_address();

    // Validate nonce
    let (account_nonce) = IAccount.get_nonce(contract_address=caller_address);
    with_attr error_message("Invalid nonce") {
        assert tx.signer_nonce = account_nonce;
    }

    // Validate gas
    with_attr error_message("Gas limit too high") {
        assert [range_check_ptr] = tx.gas_limit;
        let range_check_ptr = range_check_ptr + 1;
        assert_le(tx.gas_limit, 2 ** 64 - 1);
    }

    with_attr error_message("Max fee per gas too high") {
        assert [range_check_ptr] = tx.max_fee_per_gas;
        let range_check_ptr = range_check_ptr + 1;
    }

    let (block_gas_limit) = Kakarot.get_block_gas_limit();
    with_attr error_message("Transaction gas_limit > Block gas_limit") {
        assert_nn(block_gas_limit - tx.gas_limit);
    }

    let (block_base_fee) = Kakarot.get_base_fee();
    with_attr error_message("Max fee per gas too low") {
        assert_nn(tx.max_fee_per_gas - block_base_fee);
    }

    with_attr error_message("Max priority fee greater than max fee per gas") {
        assert [range_check_ptr] = tx.max_priority_fee_per_gas;
        let range_check_ptr = range_check_ptr + 1;
        assert_le(tx.max_priority_fee_per_gas, tx.max_fee_per_gas);
    }

    let (evm_address) = IAccount.get_evm_address(caller_address);
    let (balance) = eth_get_balance(evm_address);
    let max_gas_fee = tx.gas_limit * tx.max_fee_per_gas;
    let (max_fee_high, max_fee_low) = split_felt(max_gas_fee);
    let (tx_cost, carry) = uint256_add(tx.amount, Uint256(low=max_fee_low, high=max_fee_high));
    assert carry = 0;
    let (is_balance_enough) = uint256_le(tx_cost, balance);
    with_attr error_message("Not enough ETH to pay msg.value + max gas fees") {
        assert is_balance_enough = TRUE;
    }

    let possible_priority_fee = tx.max_fee_per_gas - block_base_fee;
    let priority_fee_is_max_priority_fee = is_nn(
        possible_priority_fee - tx.max_priority_fee_per_gas
    );
    let priority_fee_per_gas = priority_fee_is_max_priority_fee * tx.max_priority_fee_per_gas + (
        1 - priority_fee_is_max_priority_fee
    ) * possible_priority_fee;
    let effective_gas_price = priority_fee_per_gas + block_base_fee;

    let (return_data_len, return_data, success, gas_used) = eth_send_transaction(
        to=tx.destination,
        gas_limit=tx.gas_limit,
        gas_price=effective_gas_price,
        value=tx.amount,
        data_len=tx.payload_len,
        data=tx.payload,
        access_list_len=tx.access_list_len,
        access_list=tx.access_list,
    );

    return (return_data_len, return_data, success, gas_used);
}
