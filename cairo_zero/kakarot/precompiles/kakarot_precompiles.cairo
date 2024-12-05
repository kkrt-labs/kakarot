%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import call_contract, library_call, get_caller_address
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.bool import FALSE, TRUE
from starkware.cairo.common.uint256 import Uint256, uint256_lt

from kakarot.errors import Errors
from kakarot.interfaces.interfaces import IAccount
from kakarot.account import Account
from kakarot.constants import Constants
from utils.utils import Helpers
from backend.starknet import Starknet

// @dev The minimum number of bytes in an EVM encoded starknet call
// An EVM encoded starknet call is formatted as:
// [starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]
// The data is a 256 bits array that can be of any length.
const MIN_EVM_ENCODED_STARKNET_CALL_BYTES = 4 * 32;  // [starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32]

// @dev The number of bytes encoding the number of calls in a multicall Cairo precompile
const NUMBER_OF_CALLS_BYTES = 32;

// TODO: compute acceptable EVM gas values for Cairo execution
const CAIRO_PRECOMPILE_GAS = 10000;

// ! Contains precompiles that are specific to Kakarot.
// !
// ! Kakarot extends the features of the EVM by allowing communication between Cairo and EVM contracts,
// ! and the sending of transactions to L1.
// !
// ! There are various considerations that one must take into account when using these precompiles.
// ! We currently have 3 different "precompiles".
// ! - 0x75001: Whitelisted Cairo Precompile. Allows any whitelisted caller to execute a Cairo call.
// ! The whitelisting is based on the address of the caller. 75001 can be called using DELEGATECALL
// ! / CALLCODE. Any contract calling 75001 must be whitelisted, as malicious contract would be able
// ! to execute arbitrary actions on behalf of the caller due to the use of DELEGATECALL / CALLCODE.
// ! The biggest use case for this precompile is the mechanism of `DualVmToken`, which allows a
// ! Solidity contract to wrap a Starknet ERC20 token and interact with it as if it were an ERC20
// ! token on Ethereum.
// ! A contract should never be whitelisted for usage without extensive review and
// ! auditing.
// !
// ! - 0x75003: Multicall Precompile. Allows the caller to execute `n` Cairo calls in a single
// ! precompile call. This precompile cannot be called with DELEGATECALL / CALLCODE. As such, it can
// ! be used permissionlessly by any contract.
// !
// ! - 0x75004: Cairo Call Precompile. Allows the caller to execute a single Cairo call.  This
// ! precompile cannot be called with DELEGATECALL / CALLCODE. As such, it can be used
// ! permissionlessly by any contract.
// !
namespace KakarotPrecompiles {
    // @notice Executes a cairo contract/class.
    // @dev If called with 0x75001, the caller _must_ be whitelisted beforehand, as this could be
    // called by CALLCODE / DELEGATECALL.
    // @dev If called with 0x75004, the caller can be anyone, as DELEGATECALL / CALLCODE are not
    // allowed, which _must_ be enforced upstream.
    // @dev The input is formatted as:
    // @dev [starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]
    // @param input_len The length of the input in bytes.
    // @param input The input data.
    // @param caller_address The address of the caller of the precompile. Delegatecall rules apply.
    func cairo_call_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*, caller_address: felt) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least MIN_EVM_ENCODED_STARKNET_CALL_BYTES bytes long to be valid.
        let is_call_invalid = is_nn(MIN_EVM_ENCODED_STARKNET_CALL_BYTES - (input_len + 1));
        if (is_call_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        let (is_err, to_address, selector, calldata_len, calldata, _) = Internals.parse_cairo_call(
            evm_encoded_call_len=input_len, evm_encoded_call_ptr=input
        );

        if (is_err != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.precompileInputError();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        return Internals.execute_cairo_call(
            caller_address, to_address, selector, calldata_len, calldata, skip_returndata=FALSE
        );
    }

    // @notice Executes a batch of calls to cairo contracts.
    // @dev Cannot be called with CALLCODE / DELEGATECALL - _must_ be enforced upstream.
    // @dev The input is formatted as:
    // @dev [number_of_calls: bytes32]
    // @dev [to_1: bytes32][selector_1:bytes32][calldata_offset_1: bytes32][calldata_len_1: bytes32][calldata_1: bytes[]]...[to_n:bytes32]...
    // @param input_len The length of the input in bytes.
    // @param input The input data.
    // @param caller_address The address of the caller of the precompile.
    // @returns output_len The length in bytes of the output of the first call that reverted else 0.
    // @returns output The output data of the first call that reverted else empty.
    // @returns gas_used The gas used.
    // @returns reverted Errors.EXCEPTIONAL_HALT if a call reverted, FALSE otherwise.
    func cairo_multicall_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(input_len: felt, input: felt*, caller_address: felt) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least NUMBER_OF_CALLS_BYTES bytes long.
        let is_input_invalid = is_nn(NUMBER_OF_CALLS_BYTES - (input_len + 1));
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        let number_of_calls_ptr = input;
        // We enforce the number of calls to be at most 2 bytes.
        let invalid_number_of_calls_len = Helpers.bytes_to_felt(30, number_of_calls_ptr);
        if (invalid_number_of_calls_len != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.precompileInputError();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        let number_of_calls = Helpers.bytes2_to_felt(number_of_calls_ptr + 30);
        let gas_cost = number_of_calls * CAIRO_PRECOMPILE_GAS;
        let calls_ptr = number_of_calls_ptr + NUMBER_OF_CALLS_BYTES;
        let calls_len = input_len - NUMBER_OF_CALLS_BYTES;

        let (
            output_len, output, reverted, nb_executed_calls
        ) = Internals.execute_multiple_cairo_calls(caller_address, calls_len, calls_ptr, 0);

        if (reverted == FALSE and nb_executed_calls != number_of_calls) {
            with_attr error_message("Number of executed calls does not match precompile input") {
                assert nb_executed_calls = number_of_calls;
            }
        }

        return (output_len, output, gas_cost, reverted);
    }
}

namespace Internals {
    // @notice Takes an array of cairo calls and executes them.
    // @dev If any of the internal calls revert, the entire batch reverts.
    // @param caller_address The address of the caller of the precompile.
    // @param calls_len The length of the calls array.
    // @param calls The calls to execute.
    // @returns output_len The length in bytes of the output of the first call that reverted else 0.
    // @returns output The output data of the first call that reverted else empty.
    // @returns gas_used The gas used.
    // @returns reverted Errors.EXCEPTIONAL_HALT if reverted, FALSE otherwise.
    func execute_multiple_cairo_calls{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(caller_address: felt, calls_len: felt, calls: felt*, nb_executed_calls: felt) -> (
        output_len: felt, output: felt*, reverted: felt, nb_executed_calls: felt
    ) {
        alloc_locals;

        if (calls_len == 0) {
            let (output) = alloc();
            return (0, output, FALSE, nb_executed_calls);
        }

        // Ensure that the current remaining calls_len >= MIN_EVM_ENCODED_STARKNET_CALL_BYTES
        // Otherwise the input is malformed
        let is_input_invalid = is_nn(MIN_EVM_ENCODED_STARKNET_CALL_BYTES - (calls_len + 1));
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT, nb_executed_calls);
        }

        let (
            is_err, to_address, selector, calldata_len, calldata, next_call_offset
        ) = parse_cairo_call(evm_encoded_call_len=calls_len, evm_encoded_call_ptr=calls);

        if (is_err != FALSE) {
            let (revert_reason_len, revert_reason) = Errors.precompileInputError();
            return (revert_reason_len, revert_reason, Errors.EXCEPTIONAL_HALT, nb_executed_calls);
        }

        let (output_len, output, gas_used, reverted) = execute_cairo_call(
            caller_address, to_address, selector, calldata_len, calldata, skip_returndata=TRUE
        );

        if (reverted != FALSE) {
            return (output_len, output, reverted, nb_executed_calls + 1);
        }

        // Move to the next call
        return execute_multiple_cairo_calls(
            caller_address,
            calls_len - next_call_offset,
            calls + next_call_offset,
            nb_executed_calls + 1,
        );
    }

    // @notice Executes a call to a cairo contract
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
        to_starknet_address: felt,
        starknet_selector: felt,
        data_len: felt,
        data: felt*,
        skip_returndata: felt,
    ) -> (output_len: felt, output: felt*, gas_used: felt, reverted: felt) {
        alloc_locals;

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

    // @notice Parses a single Cairo call from the input data
    // @param evm_encoded_call_ptr Pointer to the start of the evm encoded starknet call
    // in form : [to_address: bytes32][selector: bytes32][calldata_len_offset: bytes32][calldata_len: bytes32][calldata: bytes[]]
    // @return is_err 0 if the operation is successful, 1 otherwise
    // @return to_addr The Starknet address to call
    // @return selector The selector of the function to call
    // @return calldata_len The length of the call data
    // @return calldata Pointer to the call data
    // @return next_call_offset The offset to the next call in the input
    func parse_cairo_call{range_check_ptr}(
        evm_encoded_call_len: felt, evm_encoded_call_ptr: felt*
    ) -> (
        is_err: felt,
        to_address: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
        next_call_offset: felt,
    ) {
        alloc_locals;

        // Ensure that evm_encoded_call_len is at least MIN_EVM_ENCODED_STARKNET_CALL_BYTES
        let is_input_invalid = is_nn(
            MIN_EVM_ENCODED_STARKNET_CALL_BYTES - (evm_encoded_call_len + 1)
        );
        if (is_input_invalid != 0) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }

        // Check that the to_address is a valid felt252
        let to_address_256 = Helpers.bytes32_to_uint256(evm_encoded_call_ptr);
        let (is_bigger_than_prime) = uint256_lt(
            Uint256(Constants.FELT252_PRIME_LOW, Constants.FELT252_PRIME_HIGH), to_address_256
        );
        if (is_bigger_than_prime != FALSE) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }
        let to_address = to_address_256.low + 2 ** 128 * to_address_256.high;

        // Check that the selector is a valid felt252
        let selector_ptr = evm_encoded_call_ptr + 32;
        let selector_256 = Helpers.bytes32_to_uint256(selector_ptr);
        let (is_bigger_than_prime) = uint256_lt(
            Uint256(Constants.FELT252_PRIME_LOW, Constants.FELT252_PRIME_HIGH), selector_256
        );
        if (is_bigger_than_prime != FALSE) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }
        let selector = selector_256.low + 2 ** 128 * selector_256.high;

        // Check that the calldata_len_offset is valid (< 2**128 as otherwise the gas cost would be too high)
        let calldata_len_offset_ptr = selector_ptr + 32;
        let calldata_len_offset_256 = Helpers.bytes32_to_uint256(calldata_len_offset_ptr);
        let is_valid_calldata_len_offset = Helpers.is_zero(calldata_len_offset_256.high);
        if (is_valid_calldata_len_offset == FALSE) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }
        let calldata_len_offset = calldata_len_offset_256.low;

        // Check that the data_len, located in [calldata_len_offset: calldata_len_offset+32], is within the bounds of the input
        let is_calldata_len_invalid = is_nn(
            (calldata_len_offset + 32) - (evm_encoded_call_len + 1)
        );
        if (is_calldata_len_invalid != 0) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }
        let calldata_len_ptr = evm_encoded_call_ptr + calldata_len_offset;

        // Check that the data_len is at most 2 bytes.
        let invalid_calldata_words_len = Helpers.bytes_to_felt(30, calldata_len_ptr);
        if (invalid_calldata_words_len != FALSE) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }

        let calldata_words_len = Helpers.bytes2_to_felt(calldata_len_ptr + 30);
        let calldata_bytes_len = calldata_words_len * 32;
        let calldata_offset = calldata_len_offset + 32;

        // Check that the data, located in [calldata_offset, calldata_offset + calldata_bytes_len], is within the bounds of the input
        let is_calldata_invalid = is_nn(
            (calldata_offset + calldata_bytes_len) - (evm_encoded_call_len + 1)
        );
        if (is_calldata_invalid != 0) {
            let (empty) = alloc();
            return (TRUE, 0, 0, 0, empty, 0);
        }
        let calldata_ptr = calldata_len_ptr + 32;

        // This doesn't check for individual values overflowing PRIME.
        let (calldata_len, calldata) = Helpers.load_256_bits_array(
            calldata_bytes_len, calldata_ptr
        );

        let next_call_offset = MIN_EVM_ENCODED_STARKNET_CALL_BYTES + calldata_bytes_len;

        return (FALSE, to_address, selector, calldata_len, calldata, next_call_offset);
    }
}
