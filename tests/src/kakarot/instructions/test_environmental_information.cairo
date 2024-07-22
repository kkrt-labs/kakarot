// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import ALL_ONES
from kakarot.instructions.environmental_information import EnvironmentalInformation
from kakarot.instructions.memory_operations import MemoryOperations

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
    let (calldata) = alloc();
    let evm = TestHelpers.init_evm_at_address(0, bytecode, 0, address, 0, calldata);

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
}() -> Uint256* {
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
    return extcodesize;
}

func test__exec_extcodecopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.Memory* {
    // Given
    alloc_locals;
    local size: felt;
    local offset: felt;
    local dest_offset: felt;
    local address: felt;
    %{
        ids.size = program_input["size"]
        ids.offset = program_input["offset"]
        ids.dest_offset = program_input["dest_offset"]
        ids.address = program_input["address"]
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
    }

    // Then
    assert stack.size = 0;
    return memory;
}

func test__exec_extcodecopy_zellic_issue_1258{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.Memory* {
    // Given
    alloc_locals;
    local size: felt;
    local offset_high: felt;
    local dest_offset: felt;
    local address: felt;
    %{
        ids.size = program_input["size"]
        ids.offset_high = program_input["offset_high"]
        ids.dest_offset = program_input["dest_offset"]
        ids.address = program_input["address"]
    %}
    let evm = TestHelpers.init_evm();
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();

    tempvar item_1_mstore = new Uint256(ALL_ONES, ALL_ONES);
    tempvar item_0_mstore = new Uint256(0, 0);

    tempvar item_3_extcodecopy = new Uint256(size, 0);
    tempvar item_2_extcodecopy = new Uint256(0, offset_high);
    tempvar item_1_extcodecopy = new Uint256(dest_offset, 0);
    tempvar item_0_extcodecopy = new Uint256(address, 0);

    // When
    with stack, memory, state {
        Stack.push(item_1_mstore);
        Stack.push(item_0_mstore);

        let evm = MemoryOperations.exec_mstore(evm);

        Stack.push(item_3_extcodecopy);  // size
        Stack.push(item_2_extcodecopy);  // offset
        Stack.push(item_1_extcodecopy);  // dest_offset
        Stack.push(item_0_extcodecopy);  // address
        let evm = EnvironmentalInformation.exec_extcodecopy(evm);
    }

    // Then
    assert stack.size = 0;
    return memory;
}

func test__exec_codecopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.Memory* {
    // Given
    alloc_locals;
    local size: felt;
    local offset: felt;
    local dest_offset: felt;
    local bytecode_len: felt;
    let (bytecode) = alloc();
    local opcode_number: felt;
    %{
        ids.size = program_input["size"]
        ids.offset = program_input["offset"]
        ids.dest_offset = program_input["dest_offset"]
        ids.bytecode_len = len(program_input["bytecode"])
        segments.write_arg(ids.bytecode, program_input["bytecode"])
        ids.opcode_number = program_input["opcode_number"]
    %}
    if (opcode_number == 0x37) {
        // bytecode is passed as calldata and opcode_number (first element in bytecode variable)
        // is passed as bytecode
        let evm = TestHelpers.init_evm_with_calldata(1, bytecode, bytecode_len, bytecode);
    } else {
        let evm = TestHelpers.init_evm_with_bytecode(bytecode_len, bytecode);
    }
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    tempvar item_2 = new Uint256(size, 0);
    tempvar item_1 = new Uint256(offset, 0);
    tempvar item_0 = new Uint256(dest_offset, 0);

    // When
    with stack, memory, state {
        Stack.push(item_2);  // size
        Stack.push(item_1);  // offset
        Stack.push(item_0);  // dest_offset
        let evm = EnvironmentalInformation.exec_copy(evm);
    }

    // Then
    assert stack.size = 0;
    return memory;
}

func test__exec_codecopy_offset_high_zellic_issue_1258{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() -> model.Memory* {
    // Given
    alloc_locals;
    local size: felt;
    local offset_high: felt;
    local dest_offset: felt;
    local bytecode_len: felt;
    let (bytecode) = alloc();
    local opcode_number: felt;
    %{
        ids.size = program_input["size"]
        ids.offset_high = program_input["offset_high"]
        ids.dest_offset = program_input["dest_offset"]
        ids.bytecode_len = len(program_input["bytecode"])
        segments.write_arg(ids.bytecode, program_input["bytecode"])
        ids.opcode_number = program_input["opcode_number"]
    %}
    if (opcode_number == 0x37) {
        // bytecode is passed as calldata and opcode_number (first element in bytecode variable
        // is passed as bytecode
        let evm = TestHelpers.init_evm_with_calldata(1, bytecode, bytecode_len, bytecode);
    } else {
        let evm = TestHelpers.init_evm_with_bytecode(bytecode_len, bytecode);
    }
    let stack = Stack.init();
    let state = State.init();
    let memory = Memory.init();
    tempvar item_2_exec_copy = new Uint256(size, 0);
    tempvar item_1_exec_copy = new Uint256(0, offset_high);
    tempvar item_0_exec_copy = new Uint256(dest_offset, 0);

    tempvar item_1_mstore = new Uint256(ALL_ONES, ALL_ONES);
    tempvar item_0_mstore = new Uint256(0, 0);

    // When
    with stack, memory, state {
        Stack.push(item_1_mstore);
        Stack.push(item_0_mstore);

        let evm = MemoryOperations.exec_mstore(evm);

        Stack.push(item_2_exec_copy);  // size
        Stack.push(item_1_exec_copy);  // offset
        Stack.push(item_0_exec_copy);  // dest_offset
        let evm = EnvironmentalInformation.exec_copy(evm);
    }

    // Then
    assert stack.size = 0;
    return memory;
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
}() -> Uint256* {
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
    return extcodehash;
}
