// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interfaces/MForcedWithdrawalActionState.sol";
import "../PerpetualConstants.sol";
import "../../interfaces/MFreezable.sol";
import "../../interfaces/MKeyGetters.sol";

abstract contract ForcedWithdrawals is
    PerpetualConstants,
    MForcedWithdrawalActionState,
    MFreezable,
    MKeyGetters
{
    event LogForcedWithdrawalRequest(uint256 starkKey, uint256 vaultId, uint256 quantizedAmount);

    function forcedWithdrawalRequest(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount,
        bool premiumCost
    ) external notFrozen onlyKeyOwner(starkKey) {
        // Verify vault ID in range.
        require(vaultId < PERPETUAL_POSITION_ID_UPPER_BOUND, "OUT_OF_RANGE_POSITION_ID");
        require(quantizedAmount < PERPETUAL_AMOUNT_UPPER_BOUND, "ILLEGAL_AMOUNT");

        // We cannot handle two identical forced withdraw request at the same time.
        // User can either wait for pending one to be cleared, or issue one with different amount.
        require(
            getForcedWithdrawalRequest(starkKey, vaultId, quantizedAmount) == 0,
            "REQUEST_ALREADY_PENDING"
        );

        // Start timer on escape request.
        setForcedWithdrawalRequest(starkKey, vaultId, quantizedAmount, premiumCost);

        // Log request.
        emit LogForcedWithdrawalRequest(starkKey, vaultId, quantizedAmount);
    }

    function freezeRequest(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external notFrozen {
        // Verify vaultId in range.
        require(vaultId < PERPETUAL_POSITION_ID_UPPER_BOUND, "OUT_OF_RANGE_POSITION_ID");

        // Load request time.
        uint256 requestTime = getForcedWithdrawalRequest(starkKey, vaultId, quantizedAmount);

        validateFreezeRequest(requestTime);
        freeze();
    }
}
