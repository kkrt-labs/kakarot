// SPDX-License-Identifier: MIT

%lang starknet

@storage_var
func native_token_address() -> (res: felt) {
}

@storage_var
func blockhash_registry_address() -> (res: felt) {
}

@storage_var
func contract_account_class_hash() -> (value: felt) {
}

@storage_var
func externally_owned_account_class_hash() -> (res: felt) {
}

@storage_var
func account_proxy_class_hash() -> (res: felt) {
}

// @title Constants file.
// @notice This file contains global constants.
// @author @abdelhamidbakhta
// @custom:namespace Constants
namespace Constants {
    // Define constants

    // ADDRESSES
    const ADDRESS_BYTES_LEN = 20;

    // BLOCK
    // CHAIN_ID = KKRT (0x4b4b5254) in ASCII
    const CHAIN_ID = 1263227476;
    // Coinbase address is the address of the sequencer
    const MOCK_COINBASE_ADDRESS = 0x388ca486b82e20cc81965d056b4cdcaacdffe0cf08e20ed8ba10ea97a487004;
    // Hardcode block gas limit to 20M
    const BLOCK_GAS_LIMIT = 20000000;

    // STACK
    const STACK_MAX_DEPTH = 1024;

    // GAS METERING
    const TRANSACTION_INTRINSIC_GAS_COST = 21000;

    // TRANSACTION
    // TODO: handle tx gas limit properly and remove this constant
    // Temporarily set tx gas limit to 1M gas
    const TRANSACTION_GAS_LIMIT = 1000000;

    // PRECOMPILES
    // There is no gap between precompiles addresses so we can use the last address as a reference point to determine whether an address is a precompile or not
    const LAST_PRECOMPILE_ADDRESS = 0x09;

    // PROXY
    const INITIALIZE_SELECTOR = 0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;
    const CONTRACT_ADDRESS_PREFIX = 'STARKNET_CONTRACT_ADDRESS';
    const EOA_VERSION = 0x11F2231B9D464344B81D536A50553D6281A9FA0FA37EF9AC2B9E076729AEFAA;  // pedersen("KAKAROT_AA_V0.0.1")
    const CA_VERSION = 10;

    // ACCOUNTS
    const BYTES_PER_FELT = 16;
}
