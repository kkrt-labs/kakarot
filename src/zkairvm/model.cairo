// SPDX-License-Identifier: MIT

%lang starknet

struct ExecutionContext {
    code: felt*,
    calldata: felt*,
    pc: felt,
    stopped: felt,
    return_data: felt*,
    verbose: felt,  // for debug purpose
}
