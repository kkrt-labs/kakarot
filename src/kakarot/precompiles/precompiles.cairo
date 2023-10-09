// SPDX-License-Identifier: MIT

%lang starknet
// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.math_cmp import is_le, is_not_zero

// Internal dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.precompiles.blake2f import PrecompileBlake2f
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.precompiles.ec_recover import PrecompileEcRecover
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.precompiles.sha256 import PrecompileSHA256
from kakarot.stack import Stack

// @title Precompile related functions.
// @notice This file contains functions related to the running of precompiles.
// @author @jobez
// @custom:namespace Precompile
namespace Precompiles {
    // @notice Executes a precompile at a given precompile address
    // @dev Associates gas used and precompile return values to a execution subcontext
    // @param address The precompile address to be executed
    // @param calldata_len The calldata length
    // @param calldata The calldata.
    // @param value The value.
    // @param calling_context The calling context.
    // @return ExecutionContext The initialized execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: felt,
        calldata_len: felt,
        calldata: felt*,
        value: felt,
        calling_context: model.ExecutionContext*,
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Execute the precompile at a given address
        let (output_len, output, gas_used) = _exec_precompile(address, calldata_len, calldata);

        let (local revert_contract_state_dict_start) = default_dict_new(0);
        tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
            revert_contract_state_dict_start, revert_contract_state_dict_start
        );
        // Build returned execution context
        local sub_ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=cast(0, model.CallContext*),
            program_counter=0,
            stopped=TRUE,
            return_data=output,
            return_data_len=output_len,
            stack=cast(0, model.Stack*),
            memory=cast(0, model.Memory*),
            gas_used=gas_used,
            gas_limit=0,
            gas_price=0,
            starknet_contract_address=0,
            evm_contract_address=address,
            origin=calling_context.origin,
            calling_context=calling_context,
            sub_context=cast(0, model.ExecutionContext*),
            destroy_contracts_len=0,
            destroy_contracts=cast(0, felt*),
            events_len=0,
            events=cast(0, model.Event*),
            create_addresses_len=0,
            create_addresses=cast(0, felt*),
            revert_contract_state=revert_contract_state,
            reverted=FALSE,
            read_only=FALSE,
        );

        return sub_ctx;
    }

    func is_precompile{range_check_ptr}(address: felt) -> felt {
        return is_not_zero(address) * is_le(address, Constants.LAST_PRECOMPILE_ADDRESS);
    }

    // @notice Executes associated function of precompiled address.
    // @dev This function uses an internal jump table to execute the corresponding precompile impmentation.
    // @param address The precompile address.
    // @param input_len The length of the input array.
    // @param input The input array.
    // @return output_len The output length.
    // @return output The output array.
    // @return gas_used The gas usage of precompile.
    func _exec_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, input_len: felt, input: felt*) -> (
        output_len: felt, output: felt*, gas_used: felt
    ) {
        // Compute the corresponding offset in the jump table:
        // count 1 for "next line" and 3 steps per precompile address: call, precompile, ret
        tempvar offset = 1 + 3 * address;

        // Prepare arguments
        [ap] = syscall_ptr, ap++;
        [ap] = pedersen_ptr, ap++;
        [ap] = range_check_ptr, ap++;
        [ap] = bitwise_ptr, ap++;
        [ap] = address, ap++;
        [ap] = input_len, ap++;
        [ap] = input, ap++;

        // call precompile address
        jmp rel offset;
        call unknown_precompile;  // 0x0
        ret;
        call PrecompileEcRecover.run;  // 0x1
        ret;
        call not_whitelisted_precompile;  // 0x2
        ret;
        call PrecompileRIPEMD160.run;  // 0x3
        ret;
        call PrecompileDataCopy.run;  // 0x4
        ret;
        call not_whitelisted_precompile;  // 0x5
        ret;
        call not_whitelisted_precompile;  // 0x6
        ret;
        call not_whitelisted_precompile;  // 0x7
        ret;
        call not_implemented_precompile;  // 0x8
        ret;
        call PrecompileBlake2f.run;  // 0x9
        ret;
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param address The address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func unknown_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, _input_len: felt, _input: felt*) {
        with_attr error_message("Kakarot: UnknownPrecompile {address}") {
            assert 0 = 1;
        }
        return ();
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param address The address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func not_implemented_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, _input_len: felt, _input: felt*) {
        with_attr error_message("Kakarot: NotImplementedPrecompile {address}") {
            assert 0 = 1;
        }
        return ();
    }

    // @notice A placeholder for precompile that are not implemented yet.
    // @dev Halts execution.
    // @param address The address.
    // @param _input_len The length of the input array.
    // @param _input The input array.
    func not_whitelisted_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(address: felt, _input_len: felt, _input: felt*) {
        with_attr error_message("Kakarot: NotWhitelistedPrecompile {address}") {
            assert 0 = 1;
        }
        return ();
    }
}
