// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from kakarot.precompiles.sha256 import PrecompileSHA256
from utils.utils import Helpers
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test__sha256{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(data_len: felt, data: felt*) -> (hash_len: felt, hash: felt*) {
    alloc_locals;
    let (hash_len, hash, gas_used) = PrecompileSHA256.run(
        PrecompileSHA256.PRECOMPILE_ADDRESS, data_len, data
    );
    let (minimum_word_size) = Helpers.minimum_word_count(data_len);
    assert gas_used = 3 * minimum_word_size + PrecompileSHA256.GAS_COST_SHA256;

    return (hash_len, hash);
}
