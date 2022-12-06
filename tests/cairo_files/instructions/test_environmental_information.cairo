// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.environmental_information import EnvironmentalInformation

func init_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.ExecutionContext* {
    alloc_locals;

    // Initialize CallContext
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';
    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode, bytecode_len=bytecode_len, calldata=calldata, calldata_len=1, value=0
        );

    // Initialize ExecutionContext
    let (empty_return_data: felt*) = alloc();
    let stack: model.Stack* = Stack.init();
    let memory: model.Memory* = Memory.init();
    let gas_limit = Constants.TRANSACTION_GAS_LIMIT;
    let calling_context = ExecutionContext.init_empty();
    let sub_context = ExecutionContext.init_empty();

    local ctx: model.ExecutionContext* = new model.ExecutionContext(
        call_context=call_context,
        program_counter=0,
        stopped=FALSE,
        return_data=empty_return_data,
        return_data_len=0,
        stack=stack,
        memory=memory,
        gas_used=0,
        gas_limit=gas_limit,
        intrinsic_gas_cost=0,
        starknet_contract_address=0,
        evm_contract_address=420,
        calling_context=calling_context,
        sub_context=sub_context,
        );
    return ctx;
}

@view
func test__exec_address__should_push_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let ctx: model.ExecutionContext* = init_context();

    // When
    let result = EnvironmentalInformation.exec_address(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = result.stack.len_16bytes / 2;
    assert len = 1;
    let (stack, index0) = Stack.peek(result.stack, 0);
    assert index0 = Uint256(420, 0);
    return ();
}
