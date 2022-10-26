// SPDX-License-Identifier: MIT

%lang starknet

@storage_var
func native_token_address() -> (res: felt) {
}

@storage_var
func registry_address() -> (res: felt) {
}

// @title Constants file.
// @notice This file contains global constants.
// @author @abdelhamidbakhta
// @custom:namespace Constants
namespace Constants {
    // Define constants

    // BLOCK
    // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
    const CHAIN_ID = 1263227476;
    // COINBASE address does not make sense in a StarkNet context
    // ANSWER: I think it does, and it should be the sequencer
    const MOCK_COINBASE_ADDRESS = 0x388ca486b82e20cc81965d056b4cdcaacdffe0cf08e20ed8ba10ea97a487004;

    // STACK
    const STACK_MAX_DEPTH = 1024;

    // GAS METERING
    const TRANSACTION_INTRINSIC_GAS_COST = 21000;
}
