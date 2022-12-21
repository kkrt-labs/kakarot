// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../libraries/LibConstants.sol";
import "../interfaces/MAcceptModifications.sol";
import "../interfaces/MDeposits.sol";
import "../interfaces/MTokenQuantization.sol";
import "../interfaces/MTokenAssetData.sol";
import "../interfaces/MFreezable.sol";
import "../interfaces/MKeyGetters.sol";
import "../interfaces/MTokenTransfers.sol";
import "../components/MainStorage.sol";

/**
  For a user to perform a deposit to the contract two calls need to take place:

  1. A call to an ERC20 contract, authorizing this contract to transfer funds on behalf of the user.
  2. A call to :sol:func:`deposit` indicating the starkKey, amount, asset type and target vault ID to which to send the deposit.

  The amount should be quantized, according to the specific quantization defined for the asset type.

  The result of the operation, assuming all requirements are met, is that an amount of ERC20 tokens
  equaling the amount specified in the :sol:func:`deposit` call times the quantization factor is
  transferred on behalf of the user to the contract. In addition, the contract adds the funds to an
  accumulator of pending deposits for the provided user, asset ID and vault ID.

  Once a deposit is made, the exchange may include it in a proof which will result in addition
  of the amount(s) deposited to the off-chain vault with the specified ID. When the contract
  receives such valid proof, it deducts the transfered funds from the pending deposits for the
  specified Stark key, asset ID and vault ID.

  The exchange will not be able to move the deposited funds to the off-chain vault if the Stark key
  is not registered in the system.

  Until that point, the user may cancel the deposit by performing a time-locked cancel-deposit
  operation consisting of two calls:

  1. A call to :sol:func:`depositCancel`, setting a timer to enable reclaiming the deposit. Until this timer expires the user cannot reclaim funds as the exchange may still be processing the deposit for inclusion in the off chain vault.
  2. A call to :sol:func:`depositReclaim`, to perform the actual transfer of funds from the contract back to the ERC20 contract. This will only succeed if the timer set in the previous call has expired. The result should be the transfer of all funds not accounted for in proofs for off-chain inclusion, back to the user account on the ERC20 contract.

  Calling depositCancel and depositReclaim can only be done via an ethKey that is associated with
  that vault's starkKey. This is enforced by the contract.

*/
abstract contract Deposits is
    MainStorage,
    LibConstants,
    MAcceptModifications,
    MDeposits,
    MTokenQuantization,
    MTokenAssetData,
    MFreezable,
    MKeyGetters,
    MTokenTransfers
{
    event LogDeposit(
        address depositorEthKey,
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    event LogNftDeposit(
        address depositorEthKey,
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId
    );

    event LogDepositWithTokenId(
        address depositorEthKey,
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    event LogDepositCancel(uint256 starkKey, uint256 vaultId, uint256 assetId);

    event LogDepositCancelReclaimed(
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    event LogDepositNftCancelReclaimed(
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId
    );

    event LogDepositWithTokenIdCancelReclaimed(
        uint256 starkKey,
        uint256 vaultId,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    function getDepositBalance(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId
    ) external view returns (uint256) {
        uint256 presumedAssetType = assetId;
        return fromQuantized(presumedAssetType, pendingDeposits[starkKey][assetId][vaultId]);
    }

    function getQuantizedDepositBalance(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId
    ) external view returns (uint256) {
        return pendingDeposits[starkKey][assetId][vaultId];
    }

    function depositNft(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId,
        uint256 tokenId
    ) external notFrozen {
        require(isERC721(assetType), "NOT_ERC721_TOKEN");
        depositWithTokenId(starkKey, assetType, tokenId, vaultId, 1);
    }

    function depositERC1155(
        uint256 starkKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external notFrozen {
        require(isERC1155(assetType), "NOT_ERC1155_TOKEN");
        depositWithTokenId(starkKey, assetType, tokenId, vaultId, quantizedAmount);
    }

    function depositStateUpdate(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) private returns (uint256) {
        // Checks for overflow and updates the pendingDeposits balance.
        uint256 vaultBalance = pendingDeposits[starkKey][assetId][vaultId];
        vaultBalance += quantizedAmount;
        require(vaultBalance >= quantizedAmount, "DEPOSIT_OVERFLOW");
        pendingDeposits[starkKey][assetId][vaultId] = vaultBalance;

        // Disable the cancellationRequest timeout when users deposit into their own account.
        if (
            isMsgSenderKeyOwner(starkKey) && cancellationRequests[starkKey][assetId][vaultId] != 0
        ) {
            delete cancellationRequests[starkKey][assetId][vaultId];
        }

        // Returns the updated vault balance.
        return vaultBalance;
    }

    function depositWithTokenId(
        uint256 starkKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) public notFrozen {
        // The vaultId is not validated but should be in the allowed range supported by the
        // exchange. If not, it will be ignored by the exchange and the starkKey owner may reclaim
        // the funds by using depositCancel + depositReclaim.
        require(isAssetTypeWithTokenId(assetType), "INVALID_ASSET_TYPE");

        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);

        // Updates the pendingDeposits balance and clears cancellationRequests when applicable.
        uint256 newVaultBalance = depositStateUpdate(starkKey, assetId, vaultId, quantizedAmount);

        // No need to verify amount > 0, a deposit with amount = 0 can be used to undo cancellation.
        if (isERC721(assetType)) {
            require(newVaultBalance <= 1, "ILLEGAL_ERC721_AMOUNT");
            emit LogNftDeposit(msg.sender, starkKey, vaultId, assetType, tokenId, assetId);
        }
        // Transfer the tokens to the Deposit contract.
        transferInWithTokenId(assetType, tokenId, quantizedAmount);
        // Log event.
        emit LogDepositWithTokenId(
            msg.sender,
            starkKey,
            vaultId,
            assetType,
            tokenId,
            assetId,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount
        );
    }

    function getCancellationRequest(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId
    ) external view returns (uint256 request) {
        request = cancellationRequests[starkKey][assetId][vaultId];
    }

    function depositERC20(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) public override {
        deposit(starkKey, assetType, vaultId, quantizedAmount);
    }

    // NOLINTNEXTLINE: locked-ether.
    function depositEth(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId
    ) public payable override {
        require(isEther(assetType), "INVALID_ASSET_TYPE");
        deposit(starkKey, assetType, vaultId, toQuantized(assetType, msg.value));
    }

    function deposit(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) public notFrozen {
        // The vaultId is not validated but should be in the allowed range supported by the
        // exchange. If not, it will be ignored by the exchange and the starkKey owner may reclaim
        // the funds by using depositCancel + depositReclaim.

        // No need to verify amount > 0, a deposit with amount = 0 can be used to undo cancellation.
        require(!isMintableAssetType(assetType), "MINTABLE_ASSET_TYPE");
        require(isFungibleAssetType(assetType), "NON_FUNGIBLE_ASSET_TYPE");

        uint256 assetId = assetType;

        // Updates the pendingDeposits balance and clears cancellationRequests when applicable.
        depositStateUpdate(starkKey, assetId, vaultId, quantizedAmount);

        // Transfer the tokens to the Deposit contract.
        transferIn(assetType, quantizedAmount);

        // Log event.
        emit LogDeposit(
            msg.sender,
            starkKey,
            vaultId,
            assetType,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount
        );
    }

    function deposit(
        // NOLINT: locked-ether.
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId
    ) external payable {
        require(isEther(assetType), "INVALID_ASSET_TYPE");
        deposit(starkKey, assetType, vaultId, toQuantized(assetType, msg.value));
    }

    function depositCancel(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId
    )
        external
        onlyKeyOwner(starkKey)
    // No notFrozen modifier: This function can always be used, even when frozen.
    {
        // Start the timeout.
        cancellationRequests[starkKey][assetId][vaultId] = block.timestamp;

        // Log event.
        emit LogDepositCancel(starkKey, vaultId, assetId);
    }

    function clearCancelledDeposit(
        uint256 starkKey,
        uint256 assetId,
        uint256 vaultId
    ) private returns (uint256) {
        // Make sure enough time has passed.
        uint256 requestTime = cancellationRequests[starkKey][assetId][vaultId];
        require(requestTime != 0, "DEPOSIT_NOT_CANCELED");
        uint256 freeTime = requestTime + DEPOSIT_CANCEL_DELAY;
        assert(freeTime >= DEPOSIT_CANCEL_DELAY);
        require(block.timestamp >= freeTime, "DEPOSIT_LOCKED"); // NOLINT: timestamp.

        // Clear deposit.
        uint256 quantizedAmount = pendingDeposits[starkKey][assetId][vaultId];
        delete pendingDeposits[starkKey][assetId][vaultId];
        delete cancellationRequests[starkKey][assetId][vaultId];

        // Return the cleared amount so it can be transferred back to the reclaimer.
        return quantizedAmount;
    }

    function depositReclaim(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId
    )
        external
        onlyKeyOwner(starkKey)
    // No notFrozen modifier: This function can always be used, even when frozen.
    {
        require(isFungibleAssetType(assetType), "NON_FUNGIBLE_ASSET_TYPE");

        // Clear deposit and attain the cleared amount to be transferred out.
        uint256 assetId = assetType;
        uint256 quantizedAmount = clearCancelledDeposit(starkKey, assetId, vaultId);

        // Refund deposit.
        transferOut(msg.sender, assetType, quantizedAmount);

        // Log event.
        emit LogDepositCancelReclaimed(
            starkKey,
            vaultId,
            assetType,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount
        );
    }

    function depositWithTokenIdReclaim(
        uint256 starkKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId
    )
        public
        onlyKeyOwner(starkKey)
    // No notFrozen modifier: This function can always be used, even when frozen.
    {
        require(isAssetTypeWithTokenId(assetType), "INVALID_ASSET_TYPE");

        // Clear deposit and attain the cleared amount to be transferred out.
        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);
        uint256 quantizedAmount = clearCancelledDeposit(starkKey, assetId, vaultId);

        if (quantizedAmount > 0) {
            // Refund deposit.
            transferOutWithTokenId(msg.sender, assetType, tokenId, quantizedAmount);
        }

        // Log event.
        if (isERC721(assetType)) {
            emit LogDepositNftCancelReclaimed(starkKey, vaultId, assetType, tokenId, assetId);
        }
        emit LogDepositWithTokenIdCancelReclaimed(
            starkKey,
            vaultId,
            assetType,
            tokenId,
            assetId,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount
        );
    }

    function depositNftReclaim(
        uint256 starkKey,
        uint256 assetType,
        uint256 vaultId,
        uint256 tokenId
    )
        external
        onlyKeyOwner(starkKey)
    // No notFrozen modifier: This function can always be used, even when frozen.
    {
        depositWithTokenIdReclaim(starkKey, assetType, tokenId, vaultId);
    }
}
