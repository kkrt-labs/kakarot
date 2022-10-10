// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from utils.utils import Helpers

namespace model {
    struct Stack {
        elements: Uint256*,
    }

    struct ExecutionContext {
        code: felt*,
        code_len: felt,
        calldata: felt*,
        pc: felt*,
        stopped: felt*,
        return_data: felt*,
        steps: model.ExecutionStep*,
    }

    struct ExecutionStep {
        pc: felt,
        opcode: felt,
        gas: felt,
        stack: model.Stack,
    }
}
