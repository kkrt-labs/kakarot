// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt, assert_nn
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test__datacopy_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // Given # 1
    alloc_locals;
    // When
    let result = PrecompileDataCopy.run(
        PrecompileDataCopy.PRECOMPILE_ADDRESS, calldata_len, calldata
    );

    TestHelpers.assert_array_equal(
        array_0_len=calldata_len,
        array_0=calldata,
        array_1_len=result.output_len,
        array_1=result.output,
    );
    return ();
}

@external
func test__datacopy_via_staticcall{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    local bytecode_len = 0;

    // Fill the stack with input data, following the evm.codes playground example for this opcode
    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(PrecompileDataCopy.PRECOMPILE_ADDRESS);
    let address = Uint256(address_low, address_high);
    let args_offset = Uint256(31, 0);
    let args_size = Uint256(1, 0);

    tempvar ret_offset = Uint256(63, 0);
    tempvar ret_size = Uint256(1, 0);

    let stack = Stack.push(stack, ret_size);
    let stack = Stack.push(stack, ret_offset);
    let stack = Stack.push(stack, args_size);
    let stack = Stack.push(stack, args_offset);
    let stack = Stack.push(stack, address);
    let stack = Stack.push(stack, gas);

    tempvar preset_memory = Uint256(low=0xFF, high=0);
    let memory_offset = Uint256(0, 0);
    let stack = Stack.push(stack, preset_memory);

    let stack = Stack.push(stack, memory_offset);
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);
    let ctx = MemoryOperations.exec_mstore(ctx);

    // When
    let result = SystemOperations.exec_staticcall(ctx);
    let result = CallHelper.finalize_calling_context(result);

    // Put the result alone on the stack
    let result = MemoryOperations.exec_pop(result);
    let stack = Stack.push(result.stack, Uint256(32, 0));
    let result = ExecutionContext.update_stack(result, stack);
    let result = MemoryOperations.exec_mload(result);
    let (stack, stack_result) = Stack.peek(result.stack, 0);

    // Then
    assert stack_result.low = preset_memory.low;

    return ();
}
