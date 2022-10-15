// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_eq

// Internal dependencies
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.model import model
from utils.utils import Helpers
from tests.model import EVMTestCase

namespace test_utils {
    // @notice Load Test case from file.
    // @param file_name The path to the test case file.
    func load_evm_test_case_from_file(file_name: felt) -> (evm_test_case: EVMTestCase) {
        alloc_locals;
        Helpers.setup_python_defs();
        let (code: felt*) = alloc();
        let (calldata: felt*) = alloc();
        let (expected_return_data: felt*) = alloc();
        %{
            # Load config
            import sys, json
            sys.path.append('.')
            file_name = felt_to_str(ids.file_name)
            with open(file_name, 'r') as f:
                test_case_data = json.load(f)
            code_bytes = hex_string_to_int_array(test_case_data['code'])
            for index, val in enumerate(code_bytes):
                memory[ids.code + index] = val
            calldata_bytes = hex_string_to_int_array(test_case_data['calldata'])
            for index, val in enumerate(calldata_bytes):
                memory[ids.calldata + index] = val
            expected_return_data_bytes = hex_string_to_int_array(test_case_data['expected_return_data'])
            for index, val in enumerate(expected_return_data_bytes):
                memory[ids.expected_return_data + index] = val
        %}

        let evm_test_case = EVMTestCase(
            code=code, calldata=calldata, expected_return_data=expected_return_data
        );

        return (evm_test_case=evm_test_case);
    }

    // @notice Assert that the value at the top of the stack is equal to the expected value.
    // @param ctx The pointer to the execution context.
    // @param expected_value The expected value.
    func assert_top_stack{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, expected_value: felt
    ) {
        alloc_locals;
        let (stack, actual) = Stack.pop(ctx.stack);
        let expected_uint256 = Uint256(expected_value, 0);
        let (are_equal) = uint256_eq(actual, expected_uint256);
        assert are_equal = TRUE;
        return ();
    }

    // @notice Assert that the value at the top of the stack is equal to the expected value.
    // @param ctx The pointer to the execution context.
    // @param expected_value The expected value.
    func assert_top_memory{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        ctx: model.ExecutionContext*, expected_value: felt
    ) {
        alloc_locals;
        let (memory, actual) = Memory.pop(ctx.memory);
        let expected_uint256 = Uint256(expected_value, 0);
        let (are_equal) = uint256_eq(actual, expected_uint256);
        assert are_equal = TRUE;
        return ();
    }
}
