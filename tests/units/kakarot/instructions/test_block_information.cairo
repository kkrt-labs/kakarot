// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.block_information import BlockInformation

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

func init_context{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) -> model.ExecutionContext* {
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert [code] = 00;
    let (calldata) = alloc();
    assert [calldata] = '';
    let ctx: model.ExecutionContext* = ExecutionContext.init(code, calldata);
    return ctx;
}

@external
func test__chainId__should_add_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let ctx: model.ExecutionContext* = init_context();

    // When
    let result = BlockInformation.exec_chainid(ctx);

    // Then
    assert result.gas_used = 2;
    let len: felt = Stack.len(result.stack);
    assert len = 1;
    let index0 = Stack.peek(result.stack, 0);
    assert index0 = Uint256(1263227476, 0);
    return ();
}
