%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import call_contract, library_call
from starkware.starknet.common.messages import send_message_to_l1

from kakarot.errors import Errors
from kakarot.storages import Kakarot_authorized_cairo_precompiles_callers
from utils.utils import Helpers

const CALL_CONTRACT_SOLIDITY_SELECTOR = 0xb3eb2c1b;
const LIBRARY_CALL_SOLIDITY_SELECTOR = 0x5a9af197;

const CAIRO_PRECOMPILE_GAS = 10000;

const CAIRO_MESSAGE_GAS = 5000;

namespace KakarotPrecompiles {
    func is_caller_whitelisted{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        caller_address: felt
    ) -> felt {
        let (res) = Kakarot_authorized_cairo_precompiles_callers.read(caller_address);
        return res;
    }

    func cairo_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least 4 + 3*32 bytes long.
        let is_input_invalid = is_le(input_len, 99);
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (
                revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT
            );
        }

        // Input is formatted as:
        // [selector: bytes4][starknet_address: bytes32][starknet_selector:bytes32][data_offset: bytes32][data_len: bytes32][data: bytes[]]

        // Load selector from first 4 bytes of input.
        let selector = Helpers.bytes4_to_felt(input);
        let args_ptr = input + 4;

        // Load address and cairo selector called
        // Safe to assume that the 32 bytes in input do not overflow a felt (whitelisted precompiles)
        let starknet_address = Helpers.bytes32_to_felt(args_ptr);

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
            let (retdata_size, retdata) = call_contract(
                starknet_address, starknet_selector, data_len, data
            );
            let (output) = alloc();
            let output_len = retdata_size * 32;
            Helpers.felt_array_to_bytes32_array(retdata_size, retdata, output);
            return (output_len, output, CAIRO_PRECOMPILE_GAS, 0);
        }

        if (selector == LIBRARY_CALL_SOLIDITY_SELECTOR) {
            let (retdata_size, retdata) = library_call(
                starknet_address, starknet_selector, data_len, data
            );
            let (output) = alloc();
            let output_len = retdata_size * 32;
            Helpers.felt_array_to_bytes32_array(retdata_size, retdata, output);
            return (output_len, output, CAIRO_PRECOMPILE_GAS, 0);
        }

        let (revert_reason_len, revert_reason) = Errors.invalidCairoSelector();
        return (revert_reason_len, revert_reason, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT);
    }

    func cairo_message{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(evm_address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt, reverted: felt
    ) {
        alloc_locals;

        // Input must be at least 3*32 bytes long.
        let is_input_invalid = is_le(input_len, 95);
        if (is_input_invalid != 0) {
            let (revert_reason_len, revert_reason) = Errors.outOfBoundsRead();
            return (revert_reason_len, revert_reason, CAIRO_MESSAGE_GAS, Errors.EXCEPTIONAL_HALT);
        }

        // Input is formatted as:
        // [to_address: address][data_offset: uint256][data_len: uint256][data: uint248[]]

        // Load target EVM address
        let target_address = Helpers.bytes32_to_felt(input);

        let data_offset_ptr = input + 32;
        let data_offset = Helpers.bytes32_to_felt(data_offset_ptr);
        let data_len_ptr = input + data_offset;

        // Load input data by packing all
        // If the input data is larger than the size of a felt, it will wrap around the felt size.
        let data_words_len = Helpers.bytes32_to_felt(data_len_ptr);
        let data_bytes_len = data_words_len * 32;
        let data_ptr = data_len_ptr + 32;
        let (data_len, data) = Helpers.load_256_bits_array(data_bytes_len, data_ptr);

        send_message_to_l1(target_address, data_words_len, data);
        let (output) = alloc();
        return (0, output, CAIRO_PRECOMPILE_GAS, Errors.EXCEPTIONAL_HALT);
    }
}
