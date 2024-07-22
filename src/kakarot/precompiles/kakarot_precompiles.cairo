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
from kakarot.storages import Kakarot_authorized_cairo_precompiles_callers
from utils.utils import Helpers
from backend.starknet import Starknet

const CALL_CONTRACT_SOLIDITY_SELECTOR = 0xb3eb2c1b;
const LIBRARY_CALL_SOLIDITY_SELECTOR = 0x5a9af197;

// TODO: compute acceptable EVM gas values for Cairo execution
const CAIRO_PRECOMPILE_GAS = 10000;
const CAIRO_MESSAGE_GAS = 5000;

namespace KakarotPrecompiles {
    func is_caller_whitelisted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller_address: felt
    ) -> felt {
        let (res) = Kakarot_authorized_cairo_precompiles_callers.read(caller_address);
        return res;
    }

    // @notice Executes a cairo contract/class.
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

        // Input must be at least 4 + 3*32 bytes long.
        let is_input_invalid = is_nn(99 - input_len);
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, TRUE);
        }

        // Input is formatted as:
        // [selector: bytes4][starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]

        // Load selector from first 4 bytes of input.
        let selector = Helpers.bytes4_to_felt(input);
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

        if (selector == CALL_CONTRACT_SOLIDITY_SELECTOR) {
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
                return (retdata_len, retdata, CAIRO_PRECOMPILE_GAS, TRUE);
            }

            let (output) = alloc();
            let output_len = retdata_len * 32;
            Helpers.felt_array_to_bytes32_array(retdata_len, retdata, output);
            return (output_len, output, CAIRO_PRECOMPILE_GAS, FALSE);
        }

        if (selector == LIBRARY_CALL_SOLIDITY_SELECTOR) {
            let (retdata_len, retdata) = library_call(
                to_starknet_address, starknet_selector, data_len, data
            );
            let (output) = alloc();
            let output_len = retdata_len * 32;
            Helpers.felt_array_to_bytes32_array(retdata_len, retdata, output);
            return (output_len, output, CAIRO_PRECOMPILE_GAS, FALSE);
        }

        let (revert_reason_len, revert_reason) = Errors.invalidCairoSelector();
        return (revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, TRUE);
    }

    // @notice Sends a message to a message to L1.
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

        // Input must be at least 3*32 bytes long.
        let is_input_invalid = is_nn(95 - input_len);
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, CAIRO_MESSAGE_GAS, TRUE);
        }

        // Input is formatted as:
        // [to_address: address][data_offset: uint256][data_len: uint256][data: bytes[]]

        // Load target EVM address
        let target_address = Helpers.bytes32_to_felt(input);

        let data_bytes_len = Helpers.bytes32_to_felt(input + 2 * 32);
        let data_fits_in_input = is_nn(input_len - 3 * 32 - data_bytes_len);
        if (data_fits_in_input == 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, CAIRO_MESSAGE_GAS, TRUE);
        }
        let data_ptr = input + 3 * 32;

        // TODO: implement packing mechanism that doesn't truncate 32-byte values
        // let (data_len, data) = Helpers.load_256_bits_array(data_bytes_len, data_ptr);

        send_message_to_l1(target_address, data_bytes_len, data_ptr);
        let (output) = alloc();
        return (0, output, CAIRO_MESSAGE_GAS, FALSE);
    }
}
