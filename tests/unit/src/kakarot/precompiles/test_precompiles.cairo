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
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.instructions.system_operations import SystemOperations 
from tests.unit.helpers.helpers import TestHelpers

@external
func test__precompiles_should_throw_on_not_implemented{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(_address: felt) {
    // Given
    alloc_locals;

    let (bytecode) = alloc();
    local bytecode_len = 0;

    let stack: model.Stack* = Stack.init();
    let gas = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(_address);
    let address = Uint256(address_low, address_high);
    let ctx = TestHelpers.init_context_with_stack(bytecode_len, bytecode, stack);

    // When
    let result = SystemOperations.exec_staticcall(ctx);

    return ();
}
