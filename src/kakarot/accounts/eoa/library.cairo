%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import CallContract
from starkware.cairo.common.uint256 import Uint256, uint256_not
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy

from kakarot.accounts.library import Accounts
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
        if (call_array_len == 0) {
            return ();
        }

        let (address) = evm_address.read();
        let (nonce,) = Accounts.get_nonce();
        EthTransaction.validate(
            address, nonce, [call_array].data_len, calldata + [call_array].data_offset
        );

        return validate(
            call_array_len=call_array_len - 1,
            call_array=call_array + CallArray.SIZE,
            calldata_len=calldata_len,
            calldata=calldata,
        );
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

        Accounts.increment_nonce();

        let (
            gas_price, gas_limit, destination, amount, payload_len, payload, tx_hash, v, r, s, nonce
        ) = EthTransaction.decode([call_array].data_len, calldata + [call_array].data_offset);

        let (_kakarot_address) = kakarot_address.read();
        let (return_data_len, return_data) = IKakarot.eth_send_transaction(
            contract_address=_kakarot_address,
            to=destination,
            gas_limit=gas_limit,
            gas_price=gas_price,
            value=amount,
            data_len=payload_len,
            data=payload,
        );
        memcpy(response, return_data, return_data_len);

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
