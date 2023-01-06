// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

abstract contract MForcedWithdrawalActionState {
    function forcedWithdrawActionHash(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount
    ) internal pure virtual returns (bytes32);

    function clearForcedWithdrawalRequest(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount
    ) internal virtual;

    // NOLINTNEXTLINE: external-function.
    function getForcedWithdrawalRequest(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount
    ) public view virtual returns (uint256 res);

    function setForcedWithdrawalRequest(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount,
        bool premiumCost
    ) internal virtual;
}
