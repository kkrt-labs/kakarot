// SPDX-License-Identifier: MIT

%lang starknet

struct EVMTestCase {
    code: felt*,
    calldata: felt*,
    value: felt,
    expected_return_data: felt*,
}
