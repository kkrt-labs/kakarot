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

@storage_var
func salt() -> (value: felt) {
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
    // EOA_V0.0.1 => [69, 79, 65, 95, 86, 48, 46, 48, 46, 49] => 0x454f415f56302e302e31 => pedersen hashed
    const EOA_VERSION = 0x6f5f51231e876bd085664a890c148a20ea806c5211a8ffd1a61747cf71c71d9;
    // CA_V0.0.1 => [67, 65, 95, 86, 48, 46, 48, 46, 49] => 0x43415f56302e302e31 => pedersen hashed
    const CA_VERSION = 0x7be1c12f918a11456a63db29ebfd5e477c967ae994e1bf751a7d04fa8429095;
    // ACCOUNTS
    const BYTES_PER_FELT = 16;
}
