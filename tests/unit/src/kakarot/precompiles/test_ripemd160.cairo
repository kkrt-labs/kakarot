// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.ripemd160 import PrecompileRIPEMD160
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

@external
func test__ripemd160{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}(msg_len: felt, msg: felt*) -> (hash_len: felt, hash: felt*) {
    alloc_locals;
    let (hash_len, hash, _) = PrecompileRIPEMD160.run(PrecompileRIPEMD160.PRECOMPILE_ADDRESS, msg_len, msg);

    return (hash_len, hash);
}