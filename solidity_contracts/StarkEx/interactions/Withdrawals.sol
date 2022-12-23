// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interfaces/MAcceptModifications.sol";
import "../interfaces/MTokenQuantization.sol";
import "../interfaces/MTokenAssetData.sol";
import "../interfaces/MFreezable.sol";
import "../interfaces/MKeyGetters.sol";
import "../interfaces/MTokenTransfers.sol";
import "../components/MainStorage.sol";

/**
  For a user to perform a withdrawal operation from the Stark Exchange during normal operation
  two calls are required:

  1. A call to an offchain exchange API, requesting a withdrawal from a user account (vault).
  2. A call to the on-chain :sol:func:`withdraw` function to perform the actual withdrawal of funds transferring them to the users Eth or ERC20 account (depending on the token type).

  For simplicity, hereafter it is assumed that all tokens are ERC20 tokens but the text below
  applies to Eth in the same manner.

  In the first call mentioned above, anyone can call the API to request the withdrawal of an
  amount from a given vault. Following the request, the exchange may include the withdrawal in a
  STARK proof. The submission of a proof then results in the addition of the amount(s) withdrawn to
  an on-chain pending withdrawals account under the stark key of the vault owner and the appropriate
  asset ID. At the same time, this also implies that this amount is deducted from the off-chain
  vault.

  Once the amount to be withdrawn has been transfered to the on-chain pending withdrawals account,
  the user may perform the second call mentioned above to complete the transfer of funds from the
  Stark Exchange contract to the appropriate ERC20 account. Only a user holding the Eth key
  corresponding to the Stark Key of a pending withdrawals account may perform this operation.

  It is possible that for multiple withdrawal calls to the API, a single withdrawal call to the
  contract may retrieve all funds, as long as they are all for the same asset ID.

  The result of the operation, assuming all requirements are met, is that an amount of ERC20 tokens
  in the pending withdrawal account times the quantization factor is transferred to the ERC20
  account of the user.

  A withdrawal request cannot be cancelled. Once funds reach the pending withdrawals account
  on-chain, they cannot be moved back into an off-chain vault before completion of the withdrawal
  to the ERC20 account of the user.

  In the event that the exchange reaches a frozen state the user may perform a withdrawal operation
  via an alternative flow, known as the "Escape" flow. In this flow, the API call above is replaced
  with an :sol:func:`escape` call to the on-chain contract (see :sol:mod:`Escapes`) proving the
  ownership of off-chain funds. If such proof is accepted, the user may proceed as above with
  the :sol:func:`withdraw` call to the contract to complete the operation.
*/
abstract contract Withdrawals is
    MainStorage,
    MAcceptModifications,
    MTokenQuantization,
    MTokenAssetData,
    MFreezable,
    MKeyGetters,
    MTokenTransfers
{
    event LogWithdrawalPerformed(
        uint256 ownerKey,
        uint256 assetType,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount,
        address recipient
    );

    event LogNftWithdrawalPerformed(
        uint256 ownerKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId,
        address recipient
    );

    event LogWithdrawalWithTokenIdPerformed(
        uint256 ownerKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 assetId,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount,
        address recipient
    );

    event LogMintWithdrawalPerformed(
        uint256 ownerKey,
        uint256 assetType,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount,
        uint256 assetId
    );

    function getWithdrawalBalance(uint256 ownerKey, uint256 assetId)
        external
        view
        returns (uint256)
    {
        uint256 presumedAssetType = assetId;
        return fromQuantized(presumedAssetType, pendingWithdrawals[ownerKey][assetId]);
    }

    /*
      Moves funds from the pending withdrawal account to the owner address.
      Note: this function can be called by anyone.
      Can be called normally while frozen.
    */
    function withdraw(uint256 ownerKey, uint256 assetType) external {
        address payable recipient = payable(strictGetEthKey(ownerKey));
        require(!isMintableAssetType(assetType), "MINTABLE_ASSET_TYPE");
        require(isFungibleAssetType(assetType), "NON_FUNGIBLE_ASSET_TYPE");
        uint256 assetId = assetType;
        // Fetch and clear quantized amount.
        uint256 quantizedAmount = pendingWithdrawals[ownerKey][assetId];
        pendingWithdrawals[ownerKey][assetId] = 0;

        // Transfer funds.
        transferOut(recipient, assetType, quantizedAmount);
        emit LogWithdrawalPerformed(
            ownerKey,
            assetType,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount,
            recipient
        );
    }

    /*
      Allows withdrawal of tokens to their owner's account.
      Note: this function can be called by anyone.
      This function can be called normally while frozen.
    */
    function withdrawWithTokenId(
        uint256 ownerKey,
        uint256 assetType,
        uint256 tokenId // No notFrozen modifier: This function can always be used, even when frozen.
    ) public {
        require(isAssetTypeWithTokenId(assetType), "INVALID_ASSET_TYPE");
        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);
        address recipient = strictGetEthKey(ownerKey);

        uint256 quantizedAmount = pendingWithdrawals[ownerKey][assetId];
        pendingWithdrawals[ownerKey][assetId] = 0;

        // Transfer funds.
        transferOutWithTokenId(recipient, assetType, tokenId, quantizedAmount);
        if (isERC721(assetType)) {
            emit LogNftWithdrawalPerformed(ownerKey, assetType, tokenId, assetId, recipient);
        }
        emit LogWithdrawalWithTokenIdPerformed(
            ownerKey,
            assetType,
            tokenId,
            assetId,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount,
            recipient
        );
    }

    /*
      Allows withdrawal of an NFT to its owner's account.
      Note: this function can be called by anyone.
      This function can be called normally while frozen.
    */
    function withdrawNft(
        uint256 ownerKey,
        uint256 assetType,
        uint256 tokenId // No notFrozen modifier: This function can always be used, even when frozen.
    ) external {
        withdrawWithTokenId(ownerKey, assetType, tokenId);
    }

    function withdrawAndMint(
        uint256 ownerKey,
        uint256 assetType,
        bytes calldata mintingBlob
    ) external {
        address recipient = strictGetEthKey(ownerKey);
        require(registeredAssetType[assetType], "INVALID_ASSET_TYPE");
        require(isMintableAssetType(assetType), "NON_MINTABLE_ASSET_TYPE");
        uint256 assetId = calculateMintableAssetId(assetType, mintingBlob);
        require(pendingWithdrawals[ownerKey][assetId] > 0, "NO_PENDING_WITHDRAWAL_BALANCE");
        uint256 quantizedAmount = pendingWithdrawals[ownerKey][assetId];
        pendingWithdrawals[ownerKey][assetId] = 0;
        // Transfer funds.
        transferOutMint(assetType, quantizedAmount, recipient, mintingBlob);
        emit LogMintWithdrawalPerformed(
            ownerKey,
            assetType,
            fromQuantized(assetType, quantizedAmount),
            quantizedAmount,
            assetId
        );
    }
}
