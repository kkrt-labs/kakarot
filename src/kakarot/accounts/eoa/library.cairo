%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import CallContract, get_tx_info, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_not, uint256_add, uint256_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.math import split_felt

from kakarot.account import Account
from kakarot.errors import Errors
from kakarot.interfaces.interfaces import IERC20, IKakarot
from utils.eth_transaction import EthTransaction
from utils.utils import Helpers

@storage_var
func evm_address() -> (evm_address: felt) {
}

@storage_var
func kakarot_address() -> (kakarot_address: felt) {
}

@storage_var
func is_initialized_() -> (res: felt) {
}

// Should always be zero. If not, the account has code and will fail validation.
@storage_var
func bytecode_len_() -> (res: felt) {
}

@event
func transaction_executed(response_len: felt, response: felt*, success: felt, gas_used: felt) {
}

namespace ExternallyOwnedAccount {
    // Constants
    // @dev see utils/interface_id.py
    const INTERFACE_ID = 0x68bca1a;

    struct Call {
        to: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
    }

    // Tmp struct introduced while we wait for Cairo to support passing `[Call]` to __execute__
    struct CallArray {
        to: felt,
        selector: felt,
        data_offset: felt,
        data_len: felt,
    }

    // @notice This function is used to initialize the externally owned account.
    // @param _kakarot_address The address of the kakarot contract
    // @param _evm_address The corresponding EVM address of this account
    func initialize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(_kakarot_address: felt, _evm_address) {
        let (is_initialized) = is_initialized_.read();
        assert is_initialized = 0;
        evm_address.write(_evm_address);
        kakarot_address.write(_kakarot_address);
        // Give infinite ETH transfer allowance to Kakarot
        let (native_token_address) = IKakarot.get_native_token(_kakarot_address);
        let (infinite) = uint256_not(Uint256(0, 0));
        IERC20.approve(native_token_address, _kakarot_address, infinite);
        is_initialized_.write(1);
        return ();
    }

    // @notice Read stored EVM address.
    // @return evm_address The stored address.
    func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        evm_address: felt
    ) {
        let (address) = evm_address.read();
        return (evm_address=address);
    }

    // @notice Validate the signature of every call in the call array.
    // @dev Recursively validates if tx is signed and valid for each call -> see utils/eth_transaction.cairo
    // @param call_array_len The length of the call array.
    // @param call_array The call array.
    // @param calldata_len The length of the calldata.
    // @param calldata The calldata.
    func validate{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) -> () {
        alloc_locals;
        if (call_array_len == 0) {
            // Validates that this account doesn't have code.
            let (bytecode_len) = bytecode_len_.read();
            with_attr error_message("EOAs cannot have code") {
                assert bytecode_len = 0;
            }

            return ();
        }

        let (address) = evm_address.read();
        let (tx_info) = get_tx_info();

        // Assert signature field is of length 5: r_low, r_high, s_low, s_high, v
        assert tx_info.signature_len = 5;
        let r = Uint256(tx_info.signature[0], tx_info.signature[1]);
        let s = Uint256(tx_info.signature[2], tx_info.signature[3]);
        let v = tx_info.signature[4];

        EthTransaction.validate(
            address,
            tx_info.nonce,
            tx_info.chain_id,
            r,
            s,
            v,
            [call_array].data_len,
            calldata + [call_array].data_offset,
        );

        validate(
            call_array_len=call_array_len - 1,
            call_array=call_array + CallArray.SIZE,
            calldata_len=calldata_len,
            calldata=calldata,
        );

        return ();
    }

    // @notice Execute the transaction.
    // @param call_array_len The length of the call array.
    // @param call_array The call array.
    // @param calldata_len The length of the calldata.
    // @param calldata The calldata.
    // @param response The response data array to be updated.
    // @return response_len The total length of the response data array.
    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(
        call_array_len: felt,
        call_array: CallArray*,
        calldata_len: felt,
        calldata: felt*,
        response: felt*,
    ) -> (response_len: felt) {
        alloc_locals;
        if (call_array_len == 0) {
            return (response_len=0);
        }

        let tx = EthTransaction.decode([call_array].data_len, calldata + [call_array].data_offset);

        let (_kakarot_address) = kakarot_address.read();
        let (block_gas_limit) = IKakarot.get_block_gas_limit(_kakarot_address);
        let is_block_gas_lt_tx_gas = is_le(block_gas_limit, tx.gas_limit + 1);

        let (base_fee) = IKakarot.get_base_fee(_kakarot_address);
        let (native_token_address) = IKakarot.get_native_token(_kakarot_address);
        let (contract_address) = get_contract_address();
        let (balance) = IERC20.balanceOf(native_token_address, contract_address);

        // ensure that the user was willing to at least pay the base fee
        let enough_fee = is_le(base_fee, tx.max_fee_per_gas);
        let max_fee_greater_priority_fee = is_le(tx.max_priority_fee_per_gas, tx.max_fee_per_gas);
        let max_gas_fee = tx.gas_limit * tx.max_fee_per_gas;
        let (max_fee_high, max_fee_low) = split_felt(max_gas_fee);
        let (tx_cost, carry) = uint256_add(tx.amount, Uint256(low=max_fee_low, high=max_fee_high));
        assert carry = 0;
        let (is_balance_enough) = uint256_le(tx_cost, balance);

        if (enough_fee * max_fee_greater_priority_fee * is_balance_enough * is_block_gas_lt_tx_gas == 0) {
            let (return_data_len, return_data) = Errors.eth_validation_failed();
            tempvar range_check_ptr = range_check_ptr;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar return_data_len = return_data_len;
            tempvar return_data = return_data;
            tempvar success = FALSE;
            tempvar gas_used = 0;
        } else {
            // priority fee is capped because the base fee is filled first
            let possible_priority_fee = tx.max_fee_per_gas - base_fee;
            let priority_fee_is_max_priority_fee = is_le(
                tx.max_priority_fee_per_gas, possible_priority_fee
            );
            let priority_fee_per_gas = priority_fee_is_max_priority_fee *
                tx.max_priority_fee_per_gas + (1 - priority_fee_is_max_priority_fee) *
                possible_priority_fee;
            // signer pays both the priority fee and the base fee
            let effective_gas_price = priority_fee_per_gas + base_fee;

            let (return_data_len, return_data, success, gas_used) = IKakarot.eth_send_transaction(
                contract_address=_kakarot_address,
                to=tx.destination,
                gas_limit=tx.gas_limit,
                gas_price=effective_gas_price,
                value=tx.amount,
                data_len=tx.payload_len,
                data=tx.payload,
                access_list_len=tx.access_list_len,
                access_list=tx.access_list,
            );
            tempvar range_check_ptr = range_check_ptr;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar return_data_len = return_data_len;
            tempvar return_data = return_data;
            tempvar success = success;
            tempvar gas_used = gas_used;
        }
        let range_check_ptr = [ap - 7];
        let syscall_ptr = cast([ap - 6], felt*);
        let pedersen_ptr = cast([ap - 5], HashBuiltin*);
        let return_data_len = [ap - 4];
        let return_data = cast([ap - 3], felt*);
        let success = [ap - 2];
        let gas_used = [ap - 1];

        memcpy(response, return_data, return_data_len);

        // See Argent account
        // https://github.com/argentlabs/argent-contracts-starknet/blob/c6d3ee5e05f0f4b8a5c707b4094446c3bc822427/contracts/account/ArgentAccount.cairo#L132
        transaction_executed.emit(
            response_len=return_data_len, response=return_data, success=success, gas_used=gas_used
        );

        let (response_len) = execute(
            call_array_len - 1,
            call_array + CallArray.SIZE,
            calldata_len,
            calldata,
            response + return_data_len,
        );

        return (response_len=return_data_len + response_len);
    }
}
