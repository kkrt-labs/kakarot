// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.modexp import PrecompileModExpUint256
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.utils.helpers import TestHelpers

@external
func test__modexp_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(data_len: felt, data: felt*) -> (result: felt, gas_cost: felt) {
    alloc_locals;

    let (output_len, output, gas_used) = PrecompileModExpUint256.run(
        PrecompileModExpUint256.PRECOMPILE_ADDRESS, data_len, data
    );

    let (result) = Helpers.bytes_to_felt(output_len, output, 0);
    return (result=result, gas_cost=gas_used);
}
