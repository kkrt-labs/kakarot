// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.memcpy import memcpy

from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

func test__exec_address__should_push_address_to_stack{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let (bytecode) = alloc();
    let address = 0xdead;
    let evm = TestHelpers.init_evm_at_address(0, bytecode, 0, address);

    // When
    with stack, memory, state {
        let result = EnvironmentalInformation.exec_address(evm);
        let (index0) = Stack.peek(0);
    }

    // Then
    assert stack.size = 1;
    assert index0.low = address;
    assert index0.high = 0;
    return ();
}

func test__exec_extcodesize{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    local address: felt;
    %{ ids.address = program_input["address"] %}
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    // When
    with stack, memory, state {
        Stack.push_uint128(address);
        let evm = EnvironmentalInformation.exec_extcodesize(evm);
        let (extcodesize) = Stack.peek(0);
    }

    // Then
    assert [output_ptr] = extcodesize.low;
    assert [output_ptr + 1] = extcodesize.high;

    return ();
}

func test__exec_extcodecopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    local address: felt;
    local size: felt;
    local offset: felt;
    local dest_offset: felt;
    %{
        ids.address = program_input["address"]
        ids.size = program_input["size"]
        ids.offset = program_input["offset"]
        ids.dest_offset = program_input["dest_offset"]
    %}
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    tempvar item_3 = new Uint256(size, 0);
    tempvar item_2 = new Uint256(offset, 0);
    tempvar item_1 = new Uint256(dest_offset, 0);
    tempvar item_0 = new Uint256(address, 0);

    // When
    with stack, memory, state {
        Stack.push(item_3);  // size
        Stack.push(item_2);  // offset
        Stack.push(item_1);  // dest_offset
        Stack.push(item_0);  // address
        let evm = EnvironmentalInformation.exec_extcodecopy(evm);
        Memory.load_n(size, output_ptr, dest_offset);
    }

    // Then
    assert stack.size = 0;
    return ();
}

func test__exec_gasprice{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;

    // Given
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    let expected_gas_price_uint256 = Helpers.to_uint256(evm.message.env.gas_price);

    // When
    with stack, memory, state {
        let result = EnvironmentalInformation.exec_gasprice(evm);
        let (gasprice) = Stack.peek(0);
    }

    // Then
    assert_uint256_eq([gasprice], [expected_gas_price_uint256]);
    return ();
}

func test__exec_extcodehash{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(output_ptr: felt*) {
    // Given
    alloc_locals;
    local address: felt;
    %{ ids.address = program_input["address"] %}
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    // When
    with stack, memory, state {
        Stack.push_uint128(address);
        let result = EnvironmentalInformation.exec_extcodehash(evm);
        let (extcodehash) = Stack.peek(0);
    }

    // Then
    assert [output_ptr] = extcodehash.low;
    assert [output_ptr + 1] = extcodehash.high;

    return ();
}
