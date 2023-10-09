// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt, assert_nn
from starkware.cairo.common.bool import FALSE, TRUE

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.system_operations import SystemOperations
from kakarot.precompiles.precompiles import Precompiles
from tests.utils.helpers import TestHelpers

@external
func test__precompiles_should_throw_on_out_of_bounds{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) {
    // When
    let result = Precompiles.run(
        address=address,
        calldata_len=0,
        calldata=cast(0, felt*),
        value=0,
        calling_context=cast(0, model.ExecutionContext*),
    );

    return ();
}

@external
func test__is_precompile{range_check_ptr}(address: felt) -> (is_precompile: felt) {
    return (is_precompile=Precompiles.is_precompile(address));
}

@external
func test__not_implemented_precompile_should_raise_with_detailed_error_message{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) {
    // When
    let result = Precompiles.not_implemented_precompile(
        address=address, _input_len=0, _input=cast(0, felt*)
    );

    return ();
}

@external
func test__run_should_return_a_stopped_execution_context{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) {
    // When
    let calling_context = ExecutionContext.init_empty();
    let result = Precompiles.run(
        address=address,
        calldata_len=0,
        calldata=cast(0, felt*),
        value=0,
        calling_context=calling_context,
    );

    assert result.stopped = 1;
    assert result.program_counter = 0;
    assert result.stack = cast(0, model.Stack*);
    assert result.memory = cast(0, model.Memory*);

    return ();
}

@external
func test__exec_precompiles_should_throw_non_implemented_precompiler_message{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) {
    let result = Precompiles._exec_precompile(address, 0, cast(0, felt*));

    return ();
}
