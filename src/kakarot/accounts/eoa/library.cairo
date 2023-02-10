%lang starknet

from utils.utils import Helpers
from kakarot.constants import Constants
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.starknet.common.syscalls import get_tx_info, get_caller_address, call_contract
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.cairo_keccak.keccak import keccak, finalize_keccak, keccak_bigend
from utils.rlp import RLP
from utils.eth_transaction import EthTransaction
from starkware.cairo.common.math_cmp import is_le, is_le_felt, is_not_zero
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy

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
    // keccak250(ascii('execute_at_address'))
    const EXECUTE_AT_ADDRESS_SELECTOR = 175332271055223547208505378209204736960926292802627036960758298143252682610;
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
        is_initialized_.write(1);
        return ();
    }

    func get_evm_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        evm_address: felt
    ) {
        let (address) = evm_address.read();
        return (evm_address=address);
    }

    // @notice checks if tx is signed and valid for each call
    // @param call_array_len The length of the call array
    // @param call_array The call array
    // @param calldata_len The length of the calldata
    // @param calldata The calldata
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
        EthTransaction.validate(
            address, [call_array].data_len, calldata + [call_array].data_offset
        );

        return validate(
            call_array_len=call_array_len - 1,
            call_array=call_array + CallArray.SIZE,
            calldata_len=calldata_len,
            calldata=calldata,
        );
    }

    // Indexes to retrieve specific data from the EVM transaction
    // @dev Should be used (eg: `items[CHAIN_ID_IDX]`)
    const NONCE_IDX = 1;
    const MAX_PRIORITY_FEE_PER_GAS_IDX = 2;
    const MAX_FEE_PER_GAS_IDX = 3;
    const GAS_LIMIT_IDX = 4;
    const DESTINATION_IDX = 5;
    const AMOUNT_IDX = 6;
    const PAYLOAD_IDX = 7;
    const ACCESS_LIST_IDX = 8;

    // @dev 2 * len_byte + 2 * string_len (32) + v
    const SIGNATURE_LEN = 67;
    const LEGACY_SIGNATURE_LEN = 71;

    func execute{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(call_array_len: felt, call_array: CallArray*, calldata_len: felt, calldata: felt*) -> (
        response_len: felt, response: felt*
    ) {
        alloc_locals;

        let (tx_info) = get_tx_info();
        with_attr error_message("Account: deprecated tx version") {
            assert is_le_felt(1, tx_info.version) = TRUE;
        }

        let (caller) = get_caller_address();
        with_attr error_message("Account: reentrant call") {
            assert caller = 0;
        }

        let (local response: felt*) = alloc();
        let (response_len) = execute_list(call_array_len, call_array, calldata, response);

        return (response_len, response);
    }

    func execute_list{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        ecdsa_ptr: SignatureBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr,
    }(call_array_len: felt, call_array: CallArray*, calldata: felt*, response: felt*) -> (
        response_len: felt
    ) {
        alloc_locals;

        if (call_array_len == 0) {
            return (response_len=0);
        }

        local _call: Call = Call(
            to=[call_array].to,
            selector=[call_array].selector,
            calldata_len=[call_array].data_len,
            calldata=calldata + [call_array].data_offset,
            );

        let (local items: RLP.Item*) = alloc();
        let (local sub_items: RLP.Item*) = alloc();
        let (local starknet_calldata: felt*) = alloc();
        // dispatches on transaction type
        if (_call.calldata[0] == 2) {
            RLP.decode(_call.calldata_len - 1, _call.calldata + 1, items);
            RLP.decode([items].data_len, [items].data, sub_items);
            let (n) = Helpers.bytes_to_felt(
                sub_items[DESTINATION_IDX].data_len, sub_items[DESTINATION_IDX].data, 0
            );
            assert starknet_calldata[0] = n;
            let (n) = Helpers.bytes_to_felt(
                sub_items[AMOUNT_IDX].data_len, sub_items[AMOUNT_IDX].data, 0
            );
            assert starknet_calldata[1] = n;
            let (n) = Helpers.bytes_to_felt(
                sub_items[GAS_LIMIT_IDX].data_len, sub_items[GAS_LIMIT_IDX].data, 0
            );
            assert starknet_calldata[2] = n;
            local evm_calldata_len = sub_items[PAYLOAD_IDX].data_len;
            assert starknet_calldata[3] = evm_calldata_len;
            Helpers.fill_array(
                evm_calldata_len, sub_items[PAYLOAD_IDX].data, starknet_calldata + 4
            );

            let (_kakarot_address) = kakarot_address.read();
            let res = call_contract(
                contract_address=_kakarot_address,
                function_selector=EXECUTE_AT_ADDRESS_SELECTOR,
                calldata_size=4 + evm_calldata_len,
                calldata=starknet_calldata,
            );
            memcpy(response, res.retdata, res.retdata_size);
            let (response_len) = execute_list(
                call_array_len - 1,
                call_array + CallArray.SIZE,
                calldata,
                response + res.retdata_size,
            );
            return (response_len=res.retdata_size + response_len);
        } else {
            RLP.decode(_call.calldata_len, _call.calldata, items);
            RLP.decode([items].data_len, [items].data, sub_items);
            let (n) = Helpers.bytes_to_felt(sub_items[3].data_len, sub_items[3].data, 0);
            assert starknet_calldata[0] = n;
            let (n) = Helpers.bytes_to_felt(sub_items[4].data_len, sub_items[4].data, 0);
            assert starknet_calldata[1] = n;
            let (n) = Helpers.bytes_to_felt(sub_items[2].data_len, sub_items[2].data, 0);
            assert starknet_calldata[2] = n;
            local evm_calldata_len = sub_items[5].data_len;
            assert starknet_calldata[3] = evm_calldata_len;
            Helpers.fill_array(evm_calldata_len, sub_items[5].data, starknet_calldata + 4);
            let (_kakarot_address) = kakarot_address.read();
            let res = call_contract(
                contract_address=_kakarot_address,
                function_selector=0xB18CF02D874A8ACA5B6480CE1D57FA9C6C58015FD68F6B6B6DF59F63BBA85D,
                calldata_size=4 + evm_calldata_len,
                calldata=starknet_calldata,
            );
            memcpy(response, res.retdata, res.retdata_size);
            let (response_len) = execute_list(
                _call.calldata_len - 1,
                call_array + CallArray.SIZE,
                calldata,
                response + res.retdata_size,
            );
            return (response_len=res.retdata_size + response_len);
        }
    }
}
