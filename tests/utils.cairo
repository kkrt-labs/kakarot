// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc

// Internal dependencies
from tests.model import EVMTestCase

namespace test_utils {
    func load_evm_test_case_from_file(file_name: felt) -> (evm_test_case: EVMTestCase) {
        alloc_locals;
        setup_python_defs();
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

    func setup_python_defs() {
        %{
            import re, os, requests
            import array as arr

            MAX_LEN_FELT = 31
            os.environ.setdefault('DEBUG', 'True')
             
            def hex_string_to_int_array(text):
                res = []
                for i in range(0, len(text), 2):
                    res.append(int(text[i:i+2], 16))
                return res

            def cairo_bytes_to_hex(input):
                input_bytes = [val for key, val in memory.items() if key.segment_index == input.segment_index and key >= input]
                hex_str = byte_array_to_hex_string(input_bytes)
                return hex_str

            def byte_array_to_hex_string(input):
                hex_str = ''.join(map(byte_to_hex, input))
                return hex_str

            def byte_to_hex(b):
                return f'{b:02x}'

            def str_to_felt(text):
                if len(text) > MAX_LEN_FELT:
                    raise Exception("Text length too long to convert to felt.")
                return int.from_bytes(text.encode(), "big")
             
            def felt_to_str(felt):
                length = (felt.bit_length() + 7) // 8
                return felt.to_bytes(length, byteorder="big").decode("utf-8")
             
            def str_to_felt_array(text):
                return [str_to_felt(text[i:i+MAX_LEN_FELT]) for i in range(0, len(text), MAX_LEN_FELT)]
             
            def uint256_to_int(uint256):
                return uint256[0] + uint256[1]*2**128
             
            def uint256(val):
                return (val & 2**128-1, (val & (2**256-2**128)) >> 128)
             
            def hex_to_felt(val):
                return int(val, 16)

            def post_debug(json):
                if os.environ.get('DEBUG') == 'True':
                    requests.post(url="http://localhost:8000", json=json)
        %}
        return ();
    }
}
