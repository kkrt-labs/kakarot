// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.environmental_information import EnvironmentalInformation

func init_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.ExecutionContext* {
    alloc_locals;
    let (bytecode) = alloc();
    assert [bytecode] = 00;
    tempvar bytecode_len = 1;
    let (calldata) = alloc();
    assert [calldata] = '';
    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode, bytecode_len=bytecode_len, calldata=calldata, calldata_len=1, value=0
    );
    let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);
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
    let len: felt = Stack.len(result.stack);
    assert len = 1;
    let index0 = Stack.peek(result.stack, 0);
    assert index0 = Uint256(0, 0);
    return ();
}
