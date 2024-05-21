from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import call_contract, library_call

from kakarot.errors import Errors
from utils.utils import Helpers

const CALL_CONTRACT_SOLIDITY_SELECTOR = 0xb3eb2c1b;
const LIBRARY_CALL_SOLIDITY_SELECTOR = 0x5a9af197;

namespace KakarotPrecompiles {
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
            return (revert_reason_len, revert_reason, 0, Errors.EXCEPTIONAL_HALT);
        }

        // Load selector from first 4 bytes of input.
        let selector = Helpers.bytes_to_felt(4, input);
        let input = input + 4;

        // Load address and cairo selector called
        // ! TODO: Check if ok to load 32 bytes in a felt (assuming no wrong value is passed)
        let starknet_address = Helpers.bytes_to_felt(32, input);
        let starknet_selector = Helpers.bytes_to_felt(32, input + 32);
        let input = input + 64;

        // Load input data by packing all
        let data_len = Helpers.bytes_to_felt(32, input);
        let data = input + 32;

        %{ breakpoint() %}

        if (selector == CALL_CONTRACT_SOLIDITY_SELECTOR) {
            let (retdata_size, retdata) = call_contract(
                starknet_address, starknet_selector, data_len, data
            );
            return (retdata_size, retdata, 0, 0);
        }

        if (selector == LIBRARY_CALL_SOLIDITY_SELECTOR) {
            let (retdata_size, retdata) = library_call(
                starknet_address, starknet_selector, data_len, data
            );
            return (retdata_size, retdata, 0, 0);
        }

        // TODO! add custom error
        let (return_data) = alloc();
        return (0, return_data, 0, 1);
    }
}
