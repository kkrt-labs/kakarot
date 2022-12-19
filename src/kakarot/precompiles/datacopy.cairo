// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Internal dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.execution_context import ExecutionContext

// @title DataCopy precompile
// @custom:precompile
// @custom:address 0x04
// @notice This precompile serves as a cheaper way to copy data in memory
// @author @abdelhamidbakhta
// @custom:namespace PrecompileDataCopy
namespace PrecompileDataCopy {
    const PRECOMPILE_ADDRESS = 0x04;
    const GAS_COST_DATACOPY = 15;

    // @notice Run the precompile.
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (minimum_word_size) = Helpers.minimum_word_count(ctx.call_context.calldata_len);
        let (output, output_len) = data_copy(
            input=ctx.call_context.calldata, input_len=ctx.call_context.calldata_len
        );

        // Update return data
        let ctx = ExecutionContext.update_return_data(
            self=ctx, new_return_data_len=output_len, new_return_data=output
        );

        // Increment gas
        let ctx = ExecutionContext.increment_gas_used(
            self=ctx, inc_value=3 * minimum_word_size + GAS_COST_DATACOPY
        );

        return ctx;
    }

    // @notice Copies data from memory to memory
    // @param input The input data
    // @return The output data
    // @custom:entrypoint
    func data_copy(input: felt*, input_len: felt) -> (output: felt*, output_len: felt) {
        // TODO implement
        return (output=input, output_len=input_len);
    }
}
