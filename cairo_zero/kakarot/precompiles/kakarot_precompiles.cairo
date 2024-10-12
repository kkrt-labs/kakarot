%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import call_contract, library_call, get_caller_address
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.bool import FALSE, TRUE

from kakarot.errors import Errors
from kakarot.interfaces.interfaces import IAccount
from kakarot.account import Account
from kakarot.storages import Kakarot_l1_messaging_contract_address
from utils.utils import Helpers
from backend.starknet import Starknet

// @dev The minimum number of bytes in an EVM encoded starknet call
const MIN_EVM_ENCODED_STARKNET_CALL_BYTES = 4 * 32;  // [starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32]

// TODO: compute acceptable EVM gas values for Cairo execution
const CAIRO_PRECOMPILE_GAS = 10000;
const CAIRO_MESSAGE_GAS = 5000;

namespace KakarotPrecompiles {
    // @notice Executes a cairo contract/class.
    // @dev Requires a whitelisted caller, as this could be called by CALLCODE / DELEGATECALL
    // @param input_len The length of the input in bytes.
    // @param input The input data.
    // @param caller_address The address of the caller of the precompile. Delegatecall rules apply.
    func cairo_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*, caller_address: felt) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least 4 + MIN_EVM_ENCODED_STARKNET_CALL_BYTES bytes long.
        let is_input_invalid = is_nn((4 + MIN_EVM_ENCODED_STARKNET_CALL_BYTES) - (input_len + 1));
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        // Input is formatted as:
        // [selector: bytes4][starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]

        // Load selector from first 4 bytes of input.
        let call_selector = Helpers.bytes4_to_felt(input);
        let args_ptr = input + 4;

        // Load address and cairo selector called
        // Safe to assume that the 32 bytes in input do not overflow a felt (whitelisted precompiles)
        let to_starknet_address = Helpers.bytes32_to_felt(args_ptr);

        let starknet_selector_ptr = args_ptr + 32;
        let starknet_selector = Helpers.bytes32_to_felt(starknet_selector_ptr);

        let data_offset_ptr = args_ptr + 64;
        let data_offset = Helpers.bytes32_to_felt(data_offset_ptr);
        let data_len_ptr = args_ptr + data_offset;

        // Load input data by packing all
        // If the input data is larger than the size of a felt, it will wrap around the felt size.
        let data_words_len = Helpers.bytes32_to_felt(data_len_ptr);
        let data_bytes_len = data_words_len * 32;
        let data_ptr = data_len_ptr + 32;
        let (data_len, data) = Helpers.load_256_bits_array(data_bytes_len, data_ptr);

        return Internals.execute_cairo_call(
            caller_address,
            call_selector,
            to_starknet_address,
            starknet_selector,
            data_len,
            data,
            skip_returndata=FALSE,
        );
    }

    // @notice Executes a batch of call to cairo contracts.
    // @dev Cannot be called with CALLCODE / DELEGATECALL
    // @param input_len The length of the input in bytes.
    // @param input The input data.
    // @param caller_address The address of the caller of the precompile.
    func multicall_cairo_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*, caller_address: felt) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least 8 bytes long.
        let is_input_invalid = is_nn(8 - input_len);
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        // Input is formatted as:
        // [call_selector: bytes4][number_of_calls: bytes4]
        // [starknet_address_1: bytes32][starknet_selector_1:bytes32][data_offset_1: bytes32][data_len_1: bytes32][data_1: bytes[]]...

        // Load selector from first 4 bytes of input.
        let call_selector = Helpers.bytes4_to_felt(input);
        let number_of_calls_ptr = input + 4;

        // Load number of calls from next 4 bytes
        let number_of_calls = Helpers.bytes4_to_felt(number_of_calls_ptr);
        let gas_cost = number_of_calls * CAIRO_PRECOMPILE_GAS;
        let calls_ptr = number_of_calls_ptr + 4;
        let calls_len = input_len - 8;

        let (output_len, output, reverted) = Internals.execute_multiple_cairo_calls(
            caller_address, call_selector, calls_len, calls_ptr
        );
        return (output_len, output, gas_cost, reverted);
    }

    // @notice Sends a message to L1.
    // @dev Requires a whitelisted caller, as only the L2KakarotMessaging contract is allowed to send messages to L1.
    // @param input_len The length of the input in bytes.
    // @param input The input data.
    // @param caller_address unused
    func cairo_message{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*, caller_address: felt) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // TODO: implement packing mechanism that doesn't truncate 32-byte values
        // let (data_len, data) = Helpers.load_256_bits_array(data_bytes_len, data_ptr);

        let (target_address) = Kakarot_l1_messaging_contract_address.read();

        send_message_to_l1(target_address, input_len, input);
        let (output) = alloc();
        return (0, output, CAIRO_MESSAGE_GAS, FALSE);
    }
}

namespace Internals {
    // @notice Takes an array of cairo calls and executes them.
    // @dev If any of the internal calls revert, the entire batch reverts.
    // @param caller_address The address of the caller of the precompile.
    // @param calls_len The length of the calls array.
    // @param calls The calls to execute.
    // @returns reverted Errors.EXCEPTIONAL_HALT if reverted, FALSE otherwise.
    func execute_multiple_cairo_calls{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(caller_address: felt, call_selector: felt, calls_len: felt, calls: felt*) -> (
        output_len: felt, output: felt*, reverted: felt
    ) {
        alloc_locals;

        if (calls_len == 0) {
            let (output) = alloc();
            return (0, output, FALSE);
        }

        // Ensure that the current remaining calls_len  >= MIN_EVM_ENCODED_STARKNET_CALL_BYTES
        // Otherwise the input is malformed
        let is_input_invalid = is_nn(MIN_EVM_ENCODED_STARKNET_CALL_BYTES - (calls_len + 1));
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT);
        }

        // Input is formatted as an array of:
        // [starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]]

        // Load address and cairo selector called
        // Unsafe to assume that the 32 bytes in input do not overflow a felt - responsibility of the caller to format its input correctly
        let to_starknet_address = Helpers.bytes32_to_felt(calls);

        let starknet_selector_ptr = calls + 32;
        let starknet_selector = Helpers.bytes32_to_felt(starknet_selector_ptr);

        let data_offset_ptr = calls + 64;
        let data_offset = Helpers.bytes32_to_felt(data_offset_ptr);
        let data_len_ptr = calls + data_offset;

        // Load input data by packing all
        // If the input data is larger than the size of a felt, it will wrap around the felt size.
        let data_words_len = Helpers.bytes32_to_felt(data_len_ptr);
        let data_bytes_len = data_words_len * 32;
        let data_ptr = data_len_ptr + 32;
        let (data_len, data) = Helpers.load_256_bits_array(data_bytes_len, data_ptr);

        let (output_len, output, gas_used, reverted) = execute_cairo_call(
            caller_address,
            call_selector,
            to_starknet_address,
            starknet_selector,
            data_len,
            data,
            skip_returndata=TRUE,
        );

        if (reverted != FALSE) {
            return (output_len, output, reverted);
        }

        // Move to the next call
        let next_call_offset = MIN_EVM_ENCODED_STARKNET_CALL_BYTES + data_bytes_len;
        return execute_multiple_cairo_calls(
            caller_address, call_selector, calls_len - next_call_offset, calls + next_call_offset
        );
    }

    // @notice Executes a call to a cairo contract
    // @ param call_selector The selector of the evm
    // @ param to_starknet_address The starknet address of the contract to call
    // @ param starknet_selector The selector of the starknet contract to call
    // @ param data_len The length of the data to pass to the contract
    // @ param data The data to pass to the contract
    // @ param skip_returndata Whether to skip returning the returndata of the starknet call
    func execute_cairo_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        caller_address: felt,
        call_selector: felt,
        to_starknet_address: felt,
        starknet_selector: felt,
        data_len: felt,
        data: felt*,
        skip_returndata: felt,
    ) -> (output_len: felt, output: felt*, gas_used: felt, reverted: felt) {
        alloc_locals;
        let is_evm_selector_valid_ = is_evm_selector_valid(call_selector);
        if (is_evm_selector_valid_ == FALSE) {
            let (revert_reason_len, revert_reason) = Errors.invalidEvmSelector();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        let caller_starknet_address = Account.get_registered_starknet_address(caller_address);
        let is_not_deployed = Helpers.is_zero(caller_starknet_address);

        if (is_not_deployed != FALSE) {
            // Deploy account -
            // order of returned values in memory matches the explicit ones in the other branch
            Starknet.deploy(caller_address);
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
            tempvar caller_starknet_address = caller_starknet_address;
        }
        let syscall_ptr = cast([ap - 4], felt*);
        let pedersen_ptr = cast([ap - 3], HashBuiltin*);
        let range_check_ptr = [ap - 2];
        let caller_starknet_address = [ap - 1];

        let (retdata_len, retdata, success) = IAccount.execute_starknet_call(
            caller_starknet_address, to_starknet_address, starknet_selector, data_len, data
        );
        if (success == FALSE) {
            // skip formatting to bytes32 array and return revert reason directly
            return (retdata_len, retdata, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT);
        }

        let (output) = alloc();
        if (skip_returndata != FALSE) {
            return (0, output, CAIRO_PRECOMPILE_GAS, FALSE);
        }

        let output_len = retdata_len * 32;
        Helpers.felt_array_to_bytes32_array(retdata_len, retdata, output);
        return (output_len, output, CAIRO_PRECOMPILE_GAS, FALSE);
    }

    // @notice Checks if the selector is a valid EVM selector for a Cairo call.
    // @dev Currently, two selectors are supported:
    // call_contract(uint256,uint256,uint256[]) - for "regular" CallCairo Precompile
    // call_contract(bytes4, uint256,uint256,uint256[]) - for MulticallCairo Precompile
    // @param selector The selector to check.
    // @returns TRUE if the selector is valid, FALSE otherwise.
    func is_evm_selector_valid(selector: felt) -> felt {
        // call_contract(uint256,uint256,uint256[])
        if (selector == 0xb3eb2c1b) {
            return TRUE;
        }

        // call_contract(bytes4, uint256,uint256,uint256[])
        if (selector == 0xe6accf8a) {
            return TRUE;
        }
        return FALSE;
    }
}
