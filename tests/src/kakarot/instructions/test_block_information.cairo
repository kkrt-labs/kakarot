// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub, assert_uint256_eq
from starkware.cairo.common.math import assert_nn
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.registers import get_fp_and_pc

// Local dependencies
from utils.utils import Helpers
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants
from kakarot.storages import blockhash_registry_address
from kakarot.evm import EVM
from kakarot.instructions.block_information import BlockInformation
from tests.utils.helpers import TestHelpers

// Storage for testing BLOCKHASH
@storage_var
func block_number() -> (block_number: Uint256) {
}

@storage_var
func blockhash() -> (blockhash: felt) {
}

// Constructor
@constructor
func constructor{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(block_number_: Uint256, blockhash_: felt, blockhash_registry_address_: felt) {
    block_number.write(block_number_);
    blockhash.write(blockhash_);
    blockhash_registry_address.write(blockhash_registry_address_);
    return ();
}

@external
func test__exec_block_information{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(opcode: felt, stack_len: felt, stack: Uint256*) -> (
    result: Uint256, timestamp: felt, block_number: felt
) {
    // Given
    alloc_locals;
    let (bytecode) = alloc();
    assert [bytecode] = opcode;
    let stack_ = Stack.init();
    if (stack_len != 0) {
        let stack_ = Stack.push_uint256(stack_, stack[0]);
        tempvar range_check_ptr = range_check_ptr;
    } else {
        let stack_ = stack_;
        tempvar range_check_ptr = range_check_ptr;
    }
    let evm = TestHelpers.init_context_with_stack(1, bytecode, stack_);

    // When
    let evm = BlockInformation.exec_block_information(evm);

    // Then
    let (timestamp) = get_block_timestamp();
    let (block_number) = get_block_number();
    let (_, result) = Stack.peek(evm.stack, 0);
    return (result[0], timestamp, block_number);
}
