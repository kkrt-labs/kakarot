// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.memory import Memory
from kakarot.storages import blockhash_registry_address
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
}(opcode: felt, initial_stack_len: felt, initial_stack: Uint256*) -> (
    result: Uint256, timestamp: felt, block_number: felt
) {
    // Given
    alloc_locals;
    let stack = TestHelpers.init_stack_with_values(initial_stack_len, initial_stack);
    let memory = Memory.init();
    let state = State.init();
    let (bytecode) = alloc();
    assert [bytecode] = opcode;
    let evm = TestHelpers.init_evm_with_bytecode(1, bytecode);

    // When
    with stack, memory, state {
        let evm = BlockInformation.exec_block_information(evm);
        let (result) = Stack.peek(0);
    }

    // Then
    let (timestamp) = get_block_timestamp();
    let (block_number) = get_block_number();
    return (result[0], timestamp, block_number);
}
