// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

// Local dependencies
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.memory import Memory
from tests.units.kakarot.library import setup, prepare, Kakarot
from tests.model import EVMTestCase
from tests.utils import test_utils

// @title Basic EVM unit tests.
// @author @abdelhamidbakhta

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return setup();
}

@external
func test_arithmetic_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/001.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, 16);

    return ();
}

func _assert_comparison_operation{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    filename: felt, assert_result: felt
) {
    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(filename);

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, assert_result);

    return ();
}

@external
func test_comparison_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Test for LT
    _assert_comparison_operation('./tests/cases/003_lt.json', 0);

    // Test for GT
    _assert_comparison_operation('./tests/cases/003_gt.json', 1);

    // Test for SLT
    _assert_comparison_operation('./tests/cases/003_slt.json', 1);

    // Test for SGT
    _assert_comparison_operation('./tests/cases/003_sgt.json', 0);

    // Test for ISZERO
    _assert_comparison_operation('./tests/cases/003_iszero.json', 1);

    return ();
}

@external
func test_duplication_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/002.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, 3);

    return ();
}

@external
func test_memory_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/004.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the memory
    test_utils.assert_top_memory(ctx, 10);

    return ();
}

@external
func test_exchange_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/005.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, 4);

    return ();
}

@external
func test_environmental_information{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/006.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, 7);

    return ();
}

@external
func test_block_information{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // Prepare Kakarot instance
    let (local context) = prepare();

    // Load test case CHAINID
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/007.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, Constants.CHAIN_ID);

    // Load test case COINBASE
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/008.json'
    );

    // Run EVM execution
    let ctx: model.ExecutionContext* = Kakarot.execute(evm_test_case.code, evm_test_case.calldata);

    // Assert value on the top of the stack
    test_utils.assert_top_stack(ctx, Constants.COINBASE_ADDRESS);

    return ();
}
