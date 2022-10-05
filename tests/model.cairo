// SPDX-License-Identifier: MIT

%lang starknet

struct EVMTestCase {
    code: felt*,
    calldata: felt*,
    expected_return_data: felt*,
}
