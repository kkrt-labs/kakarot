// SPDX-License-Identifier: MIT

%lang starknet

// StarkWare dependencies
from starkware.cairo.common.uint256 import Uint256

namespace Constants {
    // Define constants
    const STACK_MAX_DEPTH = 1024;
    const TRANSACTION_INTRINSIC_GAS_COST = 21000;
}
