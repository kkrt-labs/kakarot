// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE

// Internal dependencies
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
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

    func assert_top_stack(expected: felt) {
        return ();
    }
}
