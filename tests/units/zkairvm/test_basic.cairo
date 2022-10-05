// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

// Local dependencies
from tests.units.zkairvm.library import setup, prepare, Zkairvm
from tests.model import EVMTestCase
from tests.utils import test_utils

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return setup();
}

@external
func test_basic_stack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    // prepare Zkairvm instance
    let (local context) = prepare();

    // run scenario
    %{ stop=start_prank(context.signers.anyone) %}

    // load test case
    let (evm_test_case: EVMTestCase) = test_utils.load_evm_test_case_from_file(
        './tests/cases/001.json'
    );

    // run EVM execution
    Zkairvm.execute(evm_test_case.code, evm_test_case.calldata);

    %{ stop() %}

    return ();
}
