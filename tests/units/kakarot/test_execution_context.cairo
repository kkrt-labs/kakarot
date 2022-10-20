// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.execution_context import ExecutionContext

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

@external
func test__init__should_return_an_empty_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    Helpers.setup_python_defs();
    let (code) = alloc();
    assert [code] = 00;
    let (calldata) = alloc();
    assert [calldata] = '';

    // When
    let result: model.ExecutionContext* = ExecutionContext.init(code, calldata);

    // Then
    assert result.code = code;
    assert result.code_len = 1;
    assert result.calldata = calldata;
    assert result.program_counter = 0;
    assert result.stopped = FALSE;
    assert result.stack.raw_len = 0;
    assert result.memory.raw_len = 0;
    assert result.gas_used = 0;
    assert result.gas_limit = 0;  // TODO: Add support for gas limit
    assert result.intrinsic_gas_cost = 0;
    return ();
}
