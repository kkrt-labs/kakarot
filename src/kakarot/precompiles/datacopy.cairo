// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

// Internal dependencies
from kakarot.execution_context import ExecutionContext

// @title DataCopy precompile
// @custom:precompile
// @custom:address 0x04
// @notice This precompile serves as a cheaper way to copy data in memory
// @author @abdelhamidbakhta
// @custom:namespace PrecompileDataCopy
namespace PrecompileDataCopy {

    const PRECOMPILE_ADDRESS = 0x04;

    // @notice Run the precompile.
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func run{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        return ctx;
    }



    // @notice Copies data from memory to memory
    // @param input The input data
    // @return The output data
    // @custom:entrypoint
    func data_copy(input: felt*, input_len: felt) -> (output: felt*, output_len: felt):
        // TODO implement
        return (output: input, output_len: input_len)
    }

}