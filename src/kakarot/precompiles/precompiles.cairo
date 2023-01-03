// SPDX-License-Identifier: MIT

%lang starknet
// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_le, is_not_zero

// Internal dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.precompiles.ecadd import PrecompileEcAdd
from kakarot.precompiles.ec_recover import PrecompileEcRecover
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
    // @return The initialized execution context.
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
        return_data_len: felt,
        return_data: felt*,
    ) -> model.ExecutionContext* {
        alloc_locals;

        // Execute the precompile at a given address
        let (output_len, output, gas_used) = _exec_precompile(address, calldata_len, calldata);

        // Copy results of precompile to return data
        memcpy(return_data, output, output_len);
        // Build returned execution context
        local sub_ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=cast(0, model.CallContext*),
            program_counter=0,
            stopped=TRUE,
            return_data=return_data,
            return_data_len=return_data_len,
            stack=cast(0, model.Stack*),
            memory=cast(0, model.Memory*),
            gas_used=gas_used,
            gas_limit=0,
            gas_price=0,
            starknet_contract_address=0,
            evm_contract_address=0,
            calling_context=calling_context,
            sub_context=cast(0, model.ExecutionContext*),
            destroy_contracts_len=0,
            destroy_contracts=cast(0, felt*),
            read_only=FALSE,
            );

        return sub_ctx;
    }

    func is_precompile{range_check_ptr}(address: felt) -> felt {
        return is_not_zero(address) * is_le(address, Constants.LAST_PRECOMPILE_ADDRESS);
    }

    // @notice Executes associated function of precompiled address
    // @dev This function uses an internal jump table to execute the corresponding precompile impmentation
    // @param address The precompile address.
    // @param input_len The length of the input array.
    // @param input The input array.
    // @return The output length, output array, and gas used of the application of the precompile.
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
        [ap] = input_len, ap++;
        [ap] = input, ap++;

        // call precompile address
        jmp rel offset;
        call not_implemented_precompile;  // 0x0
        ret;
        call PrecompileEcRecover.run;  // 0x1
        ret;
        call not_implemented_precompile;  // 0x2
        ret;
        call not_implemented_precompile;  // 0x3
        ret;
        call PrecompileDataCopy.run;  // 0x4
        ret;
        call not_implemented_precompile;  // 0x5
        ret;
        call PrecompileEcAdd.run;  // 0x6
        ret;
        call not_implemented_precompile;  // 0x7
        ret;
        call not_implemented_precompile;  // 0x8
        ret;
        call not_implemented_precompile;  // 0x9
        ret;
    }

    // @notice A placeholder for precompile that are not implemented yet
    // @dev Halts execution
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func not_implemented_precompile{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx_ptr: model.ExecutionContext*) {
        with_attr error_message("Kakarot: NotImplementedPrecompile") {
            assert 0 = 1;
        }
        return ();
    }
}
