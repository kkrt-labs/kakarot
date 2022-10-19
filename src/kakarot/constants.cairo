// SPDX-License-Identifier: MIT

%lang starknet

// @title Constants file.
// @notice This file contains global constants.
// @author @abdelhamidbakhta
// @custom:namespace Constants
namespace Constants {
    // Define constants

    // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
    const CHAIN_ID = 1263227476;
    const STACK_MAX_DEPTH = 1024;
    const TRANSACTION_INTRINSIC_GAS_COST = 21000;
    const MAX_MEMORY_OFFSET = 2 ** 64;
}
