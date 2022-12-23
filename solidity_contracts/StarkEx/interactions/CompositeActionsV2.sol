// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interfaces/MDeposits.sol";
import "../interfaces/MUsersV2.sol";

abstract contract CompositeActionsV2 is MDeposits, MUsersV2 {
    function registerAndDepositERC20(
        address ethKey,
        uint256 starkKey,
        bytes calldata signature,
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external {
        registerUser(ethKey, starkKey, signature);
        depositERC20(starkKey, assetType, vaultId, quantizedAmount);
    }

    // NOLINTNEXTLINE locked-ether.
    function registerAndDepositEth(
        address ethKey,
        uint256 starkKey,
        bytes calldata signature,
        uint256 assetType,
        uint256 vaultId
    ) external payable {
        registerUser(ethKey, starkKey, signature);
        depositEth(starkKey, assetType, vaultId);
    }
}
