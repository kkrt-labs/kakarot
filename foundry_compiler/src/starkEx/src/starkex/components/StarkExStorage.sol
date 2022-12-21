// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../components/MainStorage.sol";

/*
  Extends MainStorage, holds StarkEx App specific state (storage) variables.

  ALL State variables that are common to all applications, reside in MainStorage,
  whereas ALL the StarkEx app specific ones reside here.
*/
contract StarkExStorage is MainStorage {
    // Onchain vaults balances.
    // A map eth_address => asset_id => vault_id => quantized amount.
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) vaultsBalances;

    // Onchain vaults withdrawal lock time.
    // A map eth_address => asset_id => vault_id => lock expiration timestamp.
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) vaultsWithdrawalLocks;

    // Enforces the minimal balance requirement (as output by Cairo) on onchain vault updates.
    // When disabled, flash loans are enabled.
    bool strictVaultBalancePolicy; // NOLINT: constable-states, uninitialized-state.

    // The default time, in seconds, that an onchain vault is locked for withdrawal after a deposit.
    uint256 public defaultVaultWithdrawalLock; // NOLINT: constable-states.

    // Address of the message registry contract that is used to sign and verify L1 orders.
    address public orderRegistryAddress; // NOLINT: constable-states.

    // Reserved storage space for Extensibility.
    // Every added MUST be added above the end gap, and the __endGap size must be reduced
    // accordingly.
    // NOLINTNEXTLINE: naming-convention shadowing-abstract.
    uint256[LAYOUT_LENGTH - 5] private __endGap; // __endGap complements layout to LAYOUT_LENGTH.
}
