// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

abstract contract MStateRoot {
    function getValidiumVaultRoot() public view virtual returns (uint256);

    function getValidiumTreeHeight() public view virtual returns (uint256);

    function getRollupVaultRoot() public view virtual returns (uint256);

    function getRollupTreeHeight() public view virtual returns (uint256);

    /*
      Returns true iff vaultId is in the valid vault ids range,
      i.e. could appear in either the validium or rollup vaults trees.
    */
    function isVaultInRange(uint256 vaultId) internal view virtual returns (bool);

    /*
      Returns true if vaultId is a valid validium vault id.

      Note: when this function returns false it might mean that vaultId is invalid and does not
      guarantee that vaultId is a valid rollup vault id.
    */
    function isValidiumVault(uint256 vaultId) internal view virtual returns (bool);

    /*
      Returns true if vaultId is a valid rollup vault id.

      Note: when this function returns false it might mean that vaultId is invalid and does not
      guarantee that vaultId is a valid validium vault id.
    */
    function isRollupVault(uint256 vaultId) internal view virtual returns (bool);

    /*
      Given a valid vaultId, returns its leaf index in the validium/rollup tree.

      Note: this function does not assert the validity of vaultId, make sure to explicitly assert it
      when required.
    */
    function getVaultLeafIndex(uint256 vaultId) internal pure virtual returns (uint256);
}
