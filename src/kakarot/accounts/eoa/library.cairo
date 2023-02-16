%lang starknet

from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.interfaces.interfaces import IEth, IKakarot
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.signature import verify_eth_signature_uint256
from starkware.starknet.common.syscalls import get_tx_info, get_caller_address, call_contract
from starkware.cairo.common.uint256 import Uint256, uint256_not
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
    // keccak250(ascii('deploy_contract_account'))
    const DEPLOY_CONTRACT_ACCOUNT = 1793893178491056210152325574444006027492498768972445405939198352014726462427;
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
        // Give infinite ETH transfer allowance to Kakarot
        let (native_token_address) = IKakarot.get_native_token(_kakarot_address);
        let (infinite) = uint256_not(Uint256(0,0));
        IEth.approve(native_token_address,_kakarot_address,infinite);
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

        let (
            gas_limit, destination, amount, payload_len, payload, tx_hash, v, r, s
        ) = EthTransaction.decode([call_array].data_len, calldata + [call_array].data_offset);

        let (_kakarot_address) = kakarot_address.read();

        let (current_tx_calldata: felt*) = alloc();
        local offset;
        local selector;
        // If destination is 0, we are deploying a contract
        if (destination == 0) {
            // deploy_contract_account signature is
            // gas_limit: felt, calldata_len: felt, calldata: felt*
            assert [current_tx_calldata] = gas_limit;
            assert [current_tx_calldata + 1] = payload_len;
            assert offset = 2;
            assert selector = DEPLOY_CONTRACT_ACCOUNT;
        // Else run the bytecode of a specified contract
        }else{
            // execute_at_address signature is
            // address: felt, value: felt, gas_limit: felt, calldata_len: felt, calldata: felt*
            assert [current_tx_calldata] = destination;
            assert [current_tx_calldata + 1] = amount;
            assert [current_tx_calldata + 2] = gas_limit;
            assert [current_tx_calldata + 3] = payload_len;
            assert offset = 4;
            assert selector = DEPLOY_CONTRACT_ACCOUNT;
        }
        memcpy(current_tx_calldata + offset, payload, payload_len); 
        let res = call_contract(
            contract_address=_kakarot_address,
            function_selector=selector,
            calldata_size=offset + payload_len,
            calldata=current_tx_calldata,
        );
        memcpy(response, res.retdata, res.retdata_size);
        let (response_len) = execute(
            call_array_len - 1,
            call_array + CallArray.SIZE,
            calldata_len,
            calldata,
            response + res.retdata_size,
        );
        return (response_len=res.retdata_size + response_len);
    }
}
