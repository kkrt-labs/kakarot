// SPDX-License-Identifier: MIT

%lang starknet
// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Internal dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack

namespace Precompile {
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

        let stack: model.Stack* = Stack.init();
        let memory: model.Memory* = Memory.init();

        let (empty_array) = alloc();
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=empty_array, bytecode_len=0, calldata=calldata, calldata_len=calldata_len, value=value
            );

        let sub_context = ExecutionContext.init_empty();

        local ctx: model.ExecutionContext* = new model.ExecutionContext(
            call_context=call_context,
            program_counter=0,
            stopped=TRUE,
            return_data=return_data,
            return_data_len=return_data_len,
            stack=stack,
            memory=memory,
            gas_used=0,
            gas_limit=0,
            gas_price=0,
            starknet_contract_address=0,
            evm_contract_address=0,
            calling_context=calling_context,
            sub_context=sub_context,
            destroy_contracts_len=0,
            destroy_contracts=empty_array,
            );

        if (address == PrecompileDataCopy.PRECOMPILE_ADDRESS) {
            // do the computation of the precompile
            // fill call_args.return_data array with result

            return PrecompileDataCopy.run(ctx=ctx);
        }
        return ctx;
    }
}
