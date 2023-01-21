// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt

// Local dependencies
from utils.utils import Helpers
from utils.alt_bn128.alt_bn128_g1 import ALT_BN128, G1Point
from kakarot.precompiles.ecmul import PrecompileEcMul
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

const G1POINT_BYTES_LEN = 32;

@external
func test__ecmul_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let x: BigInt3 = uint256_to_bigint(Uint256(1, 0));
    let y: BigInt3 = uint256_to_bigint(Uint256(2, 0));
    let scalar: BigInt3 = uint256_to_bigint(Uint256(2, 0));
    let (x_bytes_len, x_bytes: felt*) = Helpers.bigint_to_bytes_array(x);
    let (y_bytes_len, y_bytes: felt*) = Helpers.bigint_to_bytes_array(y);
    let (scalar_bytes_len, scalar_bytes: felt*) = Helpers.bigint_to_bytes_array(scalar);

    // When
    let point: G1Point = G1Point(x, y);
    let (expected_point: G1Point) = ALT_BN128.ec_mul(point, scalar);
    let (bytes_expected_x_len, bytes_expected_result: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.x
    );
    let (bytes_expected_y_len, bytes_expected_y: felt*) = Helpers.bigint_to_bytes_array(
        expected_point.y
    );
    // We fill `bytes_expected_result + bytes_expected_x_len` ptr with `bytes_expected_y` elements
    Helpers.fill_array(
        bytes_expected_y_len, bytes_expected_y, bytes_expected_result + bytes_expected_x_len
    );
    let input_len = 96;
    let (input: felt*) = alloc();
    Helpers.fill_array(x_bytes_len, x_bytes, input);
    Helpers.fill_array(y_bytes_len, y_bytes, input + 32);
    Helpers.fill_array(scalar_bytes_len, scalar_bytes, input + 64);
    let (output_len, output: felt*, gas_used) = PrecompileEcMul.run(
        PrecompileEcMul.PRECOMPILE_ADDRESS, input_len, input
    );

    // Then
    TestHelpers.assert_array_equal(
        array_0_len=bytes_expected_x_len + bytes_expected_y_len,
        array_0=bytes_expected_result,
        array_1_len=output_len,
        array_1=output,
    );

    return ();
}

@external
func test__ecmul_via_staticcall{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given
    alloc_locals;

    let (bytecode: felt*) = alloc();
    local bytecode_len = 0;
    let x_uint256: Uint256 = Uint256(100000000000000000000000000, 100000000000);
    let y_uint256: Uint256 = Uint256(200000000000000000000000000, 200000000000);
    let scalar_uint256: Uint256 = Uint256(2, 0);
    // First place the parameters in memory, as in the evm.codes playground example for this precompile
    let stack: model.Stack* = Stack.init();
    // x
    let stack: model.Stack* = Stack.push(stack, x_uint256);
    let stack: model.Stack* = Stack.push(stack, Uint256(0, 0));
    let ctx: model.ExecutionContext* = TestHelpers.init_context_with_stack(
        bytecode_len, bytecode, stack
    );
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);
    // y
    let stack: model.Stack* = Stack.push(ctx.stack, y_uint256);
    let stack: model.Stack* = Stack.push(stack, Uint256(0x20, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);
    // scalar
    let stack: model.Stack* = Stack.push(ctx.stack, scalar_uint256);
    let stack: model.Stack* = Stack.push(stack, Uint256(0x40, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mstore(ctx);

    // Now prepare the stack for the call
    let gas: Uint256 = Helpers.to_uint256(Constants.TRANSACTION_GAS_LIMIT);
    let (address_high, address_low) = split_felt(PrecompileEcMul.PRECOMPILE_ADDRESS);
    let address: Uint256 = Uint256(address_low, address_high);

    let args_offset: Uint256 = Uint256(0, 0);
    let args_size: Uint256 = Uint256(0x60, 0);

    tempvar ret_offset: Uint256 = Uint256(0x60, 0);
    tempvar ret_size: Uint256 = Uint256(0x40, 0);

    let stack: model.Stack* = Stack.push(ctx.stack, ret_size);
    let stack: model.Stack* = Stack.push(stack, ret_offset);
    let stack: model.Stack* = Stack.push(stack, args_size);
    let stack: model.Stack* = Stack.push(stack, args_offset);
    let stack: model.Stack* = Stack.push(stack, address);
    let stack: model.Stack* = Stack.push(stack, gas);
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);

    // When
    let ctx: model.ExecutionContext* = SystemOperations.exec_staticcall(ctx);
    let ctx: model.ExecutionContext* = CallHelper.finalize_calling_context(ctx);

    // Put the resulting x and y on the stack
    let ctx: model.ExecutionContext* = MemoryOperations.exec_pop(ctx);
    let stack: model.Stack* = Stack.push(ctx.stack, Uint256(0x80, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mload(ctx);
    let (stack: model.Stack*, local result_y: Uint256) = Stack.peek(ctx.stack, 0);
    let stack: model.Stack* = Stack.push(stack, Uint256(0x60, 0));
    let ctx: model.ExecutionContext* = ExecutionContext.update_stack(ctx, stack);
    let ctx: model.ExecutionContext* = MemoryOperations.exec_mload(ctx);
    let (stack: model.Stack*, local result_x: Uint256) = Stack.peek(ctx.stack, 0);

    // Then
    let (x: BigInt3) = uint256_to_bigint(x_uint256);
    let (y: BigInt3) = uint256_to_bigint(y_uint256);
    let (scalar: BigInt3) = uint256_to_bigint(scalar_uint256);

    let (expected_point: G1Point) = ALT_BN128.ec_mul(G1Point(x, y), scalar);
    let (expected_x_uint256: Uint256) = bigint_to_uint256(expected_point.x);
    let (expected_y_uint256: Uint256) = bigint_to_uint256(expected_point.y);

    assert_uint256_eq(result_x, expected_x_uint256);
    assert_uint256_eq(result_y, expected_y_uint256);

    return ();
}
