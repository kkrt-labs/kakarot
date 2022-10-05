// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc

// Internal dependencies
from tests.model import EVMTestCase

namespace test_utils {
    func load_evm_test_case_from_file(file_name: felt) -> (evm_test_case: EVMTestCase) {
        let (code: felt*) = alloc();
        let (calldata: felt*) = alloc();
        let (expected_return_data: felt*) = alloc();

        let evm_test_case = EVMTestCase(
            code=code, calldata=calldata, expected_return_data=expected_return_data
        );

        return (evm_test_case=evm_test_case);
    }
}
