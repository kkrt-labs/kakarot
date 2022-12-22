// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./StarkExStorage.sol";
import "../interfaces/MVaultLocks.sol";
import "../../interfaces/MTokenTransfers.sol";
import "../../interfaces/MTokenAssetData.sol";
import "../../interfaces/MTokenQuantization.sol";

/*
  Onchain vaults deposit and withdrawal functionalities.
*/
abstract contract VaultDepositWithdrawal is
    StarkExStorage,
    MVaultLocks,
    MTokenQuantization,
    MTokenAssetData,
    MTokenTransfers
{
    event LogDepositToVault(
        address ethKey,
        uint256 assetType,
        uint256 assetId,
        uint256 vaultId,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    event LogWithdrawalFromVault(
        address ethKey,
        uint256 assetType,
        uint256 assetId,
        uint256 vaultId,
        uint256 nonQuantizedAmount,
        uint256 quantizedAmount
    );

    function getQuantizedVaultBalance(
        address ethKey,
        uint256 assetId,
        uint256 vaultId
    ) public view returns (uint256) {
        return vaultsBalances[ethKey][assetId][vaultId];
    }

    function getVaultBalance(
        address ethKey,
        uint256 assetId,
        uint256 vaultId
    ) external view returns (uint256) {
        return fromQuantized(assetId, getQuantizedVaultBalance(ethKey, assetId, vaultId));
    }

    function getQuantizedErc1155VaultBalance(
        address ethKey,
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId
    ) external view returns (uint256) {
        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);
        return vaultsBalances[ethKey][assetId][vaultId];
    }

    function updateVaultForDeposit(
        uint256 assetId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) private {
        // A default withdrawal lock is applied when deposits are made.
        applyDefaultLock(assetId, vaultId);
        // Update the balance.
        vaultsBalances[msg.sender][assetId][vaultId] += quantizedAmount;
        require(vaultsBalances[msg.sender][assetId][vaultId] >= quantizedAmount, "VAULT_OVERFLOW");
    }

    // NOLINTNEXTLINE: locked-ether.
    function depositEthToVault(uint256 assetType, uint256 vaultId) external payable {
        require(isEther(assetType), "INVALID_ASSET_TYPE");
        // Update the vault balance and apply default lock.
        uint256 quantizedAmount = toQuantized(assetType, msg.value);
        uint256 assetId = assetType;
        updateVaultForDeposit(assetId, vaultId, quantizedAmount);
        // Transfer the tokens to the contract.
        transferIn(assetType, quantizedAmount);
        // Log event.
        emit LogDepositToVault(
            msg.sender,
            assetType,
            assetId,
            vaultId,
            fromQuantized(assetId, quantizedAmount),
            quantizedAmount
        );
    }

    function depositERC20ToVault(
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external {
        require(isERC20(assetType), "NOT_ERC20_ASSET_TYPE");
        // Update the vault balance and apply default lock.
        uint256 assetId = assetType;
        updateVaultForDeposit(assetId, vaultId, quantizedAmount);
        // Transfer the tokens to the contract.
        transferIn(assetType, quantizedAmount);
        // Log event.
        emit LogDepositToVault(
            msg.sender,
            assetType,
            assetId,
            vaultId,
            fromQuantized(assetId, quantizedAmount),
            quantizedAmount
        );
    }

    function depositERC1155ToVault(
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external {
        require(isERC1155(assetType), "NOT_ERC1155_TOKEN");
        // Update the vault balance and apply default lock.
        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);
        updateVaultForDeposit(assetId, vaultId, quantizedAmount);
        // Transfer the tokens to the contract.
        transferInWithTokenId(assetType, tokenId, quantizedAmount);
        // Log event.
        emit LogDepositToVault(
            msg.sender,
            assetType,
            assetId,
            vaultId,
            fromQuantized(assetId, quantizedAmount),
            quantizedAmount
        );
    }

    function updateVaultForWithdrawal(
        uint256 assetId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) private {
        require(quantizedAmount > 0, "ZERO_WITHDRAWAL");
        // Make sure the vault is not locked for withdrawals.
        require(!isVaultLocked(msg.sender, assetId, vaultId), "VAULT_IS_LOCKED");
        // Make sure the vault contains sufficient funds.
        uint256 vaultBalance = vaultsBalances[msg.sender][assetId][vaultId];
        require(vaultBalance >= quantizedAmount, "INSUFFICIENT_BALANCE");
        // Update the balance.
        vaultsBalances[msg.sender][assetId][vaultId] = vaultBalance - quantizedAmount;
    }

    function withdrawFromVault(
        uint256 assetType,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external {
        require(isFungibleAssetType(assetType), "NON_FUNGIBLE_ASSET_TYPE");
        require(!isMintableAssetType(assetType), "MINTABLE_ASSET_TYPE");
        // Update the vault balance and check withdrawal lock.
        uint256 assetId = assetType;
        updateVaultForWithdrawal(assetId, vaultId, quantizedAmount);
        // Transfer funds.
        transferOut(msg.sender, assetType, quantizedAmount);
        // Log event.
        emit LogWithdrawalFromVault(
            msg.sender,
            assetType,
            assetId,
            vaultId,
            fromQuantized(assetId, quantizedAmount),
            quantizedAmount
        );
    }

    function withdrawErc1155FromVault(
        uint256 assetType,
        uint256 tokenId,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external {
        require(isERC1155(assetType), "NOT_ERC1155_TOKEN");
        // Update the vault balance and check withdrawal lock.
        uint256 assetId = calculateAssetIdWithTokenId(assetType, tokenId);
        updateVaultForWithdrawal(assetId, vaultId, quantizedAmount);
        // Transfer funds.
        transferOutWithTokenId(msg.sender, assetType, tokenId, quantizedAmount);
        // Log event.
        emit LogWithdrawalFromVault(
            msg.sender,
            assetType,
            assetId,
            vaultId,
            fromQuantized(assetId, quantizedAmount),
            quantizedAmount
        );
    }
}
