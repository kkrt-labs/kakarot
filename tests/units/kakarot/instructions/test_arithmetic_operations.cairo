// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.instructions.arithmetic_operations import ArithmeticOperations

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

@external
func test__add__should_add_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.add(stack);

    // Then
    assert gas_cost = 3;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(5, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__mul__should_mul_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.mul(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(6, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__sub__should_sub_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.sub(stack);

    // Then
    assert gas_cost = 3;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__div__should_div_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.div(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__sdiv__should_signed_div_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.sdiv(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__mod__should_mod_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.mod(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__smod__should_smod_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.smod(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    let index1 = Stack.peek(result, 1);
    assert index1 = Uint256(1, 0);
    return ();
}

@external
func test__addmod__should_add_0_and_1_and_div_rem_by_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.addmod(stack);

    // Then
    assert gas_cost = 8;
    let len: felt = Stack.len(result);
    assert len = 1;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(1, 0);
    return ();
}

@external
func test__mulmod__should_mul_0_and_1_and_div_rem_by_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.mulmod(stack);

    // Then
    assert gas_cost = 8;
    let len: felt = Stack.len(result);
    assert len = 1;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(0, 0);
    return ();
}

@external
func test__exp__should_exp_0_and_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.exp(stack);

    // Then
    assert gas_cost = 10;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(9, 0);
    let index1 = Stack.peek(result, 0);
    assert index1 = Uint256(9, 0);
    return ();
}

@external
func test__signextend__should_signextend_0_and_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // Given
    alloc_locals;
    let stack: model.Stack* = Stack.init();
    let stack: model.Stack* = Stack.push(stack, Uint256(1, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(2, 0));
    let stack: model.Stack* = Stack.push(stack, Uint256(3, 0));

    // When
    let (result, gas_cost) = ArithmeticOperations.signextend(stack);

    // Then
    assert gas_cost = 5;
    let len: felt = Stack.len(result);
    assert len = 2;
    let index0 = Stack.peek(result, 0);
    assert index0 = Uint256(2, 0);
    let index1 = Stack.peek(result, 0);
    assert index1 = Uint256(2, 0);
    return ();
}
