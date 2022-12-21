// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../libraries/Common.sol";
import "../interfaces/MTokenTransfers.sol";
import "../interfaces/MTokenAssetData.sol";
import "../interfaces/MTokenQuantization.sol";
import "../tokens/ERC1155/IERC1155.sol";
import "../tokens/ERC20/IERC20.sol";

/*
  Implements various transferIn and transferOut functionalities.
*/
abstract contract TokenTransfers is MTokenQuantization, MTokenAssetData, MTokenTransfers {
    using Addresses for address;
    using Addresses for address payable;

    /*
      Transfers funds from msg.sender to the exchange.
    */
    function transferIn(uint256 assetType, uint256 quantizedAmount) internal override {
        uint256 amount = fromQuantized(assetType, quantizedAmount);
        if (isERC20(assetType)) {
            if (quantizedAmount == 0) return;
            address tokenAddress = extractContractAddress(assetType);
            IERC20 token = IERC20(tokenAddress);
            uint256 exchangeBalanceBefore = token.balanceOf(address(this));
            bytes memory callData = abi.encodeWithSelector(
                token.transferFrom.selector,
                msg.sender,
                address(this),
                amount
            );
            tokenAddress.safeTokenContractCall(callData);
            uint256 exchangeBalanceAfter = token.balanceOf(address(this));
            require(exchangeBalanceAfter >= exchangeBalanceBefore, "OVERFLOW");
            // NOLINTNEXTLINE(incorrect-equality): strict equality needed.
            require(
                exchangeBalanceAfter == exchangeBalanceBefore + amount,
                "INCORRECT_AMOUNT_TRANSFERRED"
            );
        } else if (isEther(assetType)) {
            require(msg.value == amount, "INCORRECT_DEPOSIT_AMOUNT");
        } else {
            revert("UNSUPPORTED_TOKEN_TYPE");
        }
    }

    /*
      Transfers non fungible and semi fungible tokens from a user to the exchange.
    */
    function transferInWithTokenId(
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) internal override {
        require(isAssetTypeWithTokenId(assetType), "FUNGIBLE_ASSET_TYPE");

        if (isERC721(assetType)) {
            require(quantizedAmount == 1, "ILLEGAL_NFT_BALANCE");
            transferInNft(assetType, tokenId);
        } else if (quantizedAmount > 0) {
            transferInSft(assetType, tokenId, quantizedAmount);
        }
    }

    function transferInNft(uint256 assetType, uint256 tokenId) private {
        require(isERC721(assetType), "NOT_ERC721_TOKEN");
        address tokenAddress = extractContractAddress(assetType);

        tokenAddress.safeTokenContractCall(
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                tokenId
            )
        );
    }

    function transferInSft(
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) private {
        require(isERC1155(assetType), "NOT_ERC1155_TOKEN");
        if (quantizedAmount == 0) return;

        uint256 amount = fromQuantized(assetType, quantizedAmount);
        address tokenAddress = extractContractAddress(assetType);
        IERC1155 token = IERC1155(tokenAddress);
        uint256 exchangeBalanceBefore = token.balanceOf(address(this), tokenId);

        // Call an ERC1155 token transfer.
        tokenAddress.safeTokenContractCall(
            abi.encodeWithSelector(
                token.safeTransferFrom.selector,
                msg.sender,
                address(this),
                tokenId,
                amount,
                bytes("")
            )
        );

        uint256 exchangeBalanceAfter = token.balanceOf(address(this), tokenId);
        require(exchangeBalanceAfter >= exchangeBalanceBefore, "OVERFLOW");
        // NOLINTNEXTLINE(incorrect-equality): strict equality needed.
        require(
            exchangeBalanceAfter == exchangeBalanceBefore + amount,
            "INCORRECT_AMOUNT_TRANSFERRED"
        );
    }

    /*
      Transfers funds from the exchange to recipient.
    */
    function transferOut(
        address payable recipient,
        uint256 assetType,
        uint256 quantizedAmount
    ) internal override {
        // Make sure we don't accidentally burn funds.
        require(recipient != address(0x0), "INVALID_RECIPIENT");
        uint256 amount = fromQuantized(assetType, quantizedAmount);
        if (isERC20(assetType)) {
            if (quantizedAmount == 0) return;
            address tokenAddress = extractContractAddress(assetType);
            IERC20 token = IERC20(tokenAddress);
            uint256 exchangeBalanceBefore = token.balanceOf(address(this));
            bytes memory callData = abi.encodeWithSelector(
                token.transfer.selector,
                recipient,
                amount
            );
            tokenAddress.safeTokenContractCall(callData);
            uint256 exchangeBalanceAfter = token.balanceOf(address(this));
            require(exchangeBalanceAfter <= exchangeBalanceBefore, "UNDERFLOW");
            // NOLINTNEXTLINE(incorrect-equality): strict equality needed.
            require(
                exchangeBalanceAfter == exchangeBalanceBefore - amount,
                "INCORRECT_AMOUNT_TRANSFERRED"
            );
        } else if (isEther(assetType)) {
            if (quantizedAmount == 0) return;
            recipient.performEthTransfer(amount);
        } else {
            revert("UNSUPPORTED_TOKEN_TYPE");
        }
    }

    /*
      Transfers non fungible and semi fungible tokens from the exchange to recipient.
    */
    function transferOutWithTokenId(
        address recipient,
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) internal override {
        require(isAssetTypeWithTokenId(assetType), "FUNGIBLE_ASSET_TYPE");
        if (isERC721(assetType)) {
            require(quantizedAmount == 1, "ILLEGAL_NFT_BALANCE");
            transferOutNft(recipient, assetType, tokenId);
        } else if (quantizedAmount > 0) {
            transferOutSft(recipient, assetType, tokenId, quantizedAmount);
        }
    }

    /*
      Transfers NFT from the exchange to recipient.
    */
    function transferOutNft(
        address recipient,
        uint256 assetType,
        uint256 tokenId
    ) private {
        // Make sure we don't accidentally burn funds.
        require(recipient != address(0x0), "INVALID_RECIPIENT");
        require(isERC721(assetType), "NOT_ERC721_TOKEN");
        address tokenAddress = extractContractAddress(assetType);

        tokenAddress.safeTokenContractCall(
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(this),
                recipient,
                tokenId
            )
        );
    }

    /*
      Transfers Semi Fungible Tokens from the exchange to recipient.
    */
    function transferOutSft(
        address recipient,
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) private {
        // Make sure we don't accidentally burn funds.
        require(recipient != address(0x0), "INVALID_RECIPIENT");
        require(isERC1155(assetType), "NOT_ERC1155_TOKEN");
        if (quantizedAmount == 0) return;

        uint256 amount = fromQuantized(assetType, quantizedAmount);
        address tokenAddress = extractContractAddress(assetType);
        IERC1155 token = IERC1155(tokenAddress);
        uint256 exchangeBalanceBefore = token.balanceOf(address(this), tokenId);

        // Call an ERC1155 token transfer.
        tokenAddress.safeTokenContractCall(
            abi.encodeWithSelector(
                token.safeTransferFrom.selector,
                address(this),
                recipient,
                tokenId,
                amount,
                bytes("")
            )
        );

        uint256 exchangeBalanceAfter = token.balanceOf(address(this), tokenId);
        require(exchangeBalanceAfter <= exchangeBalanceBefore, "UNDERFLOW");
        // NOLINTNEXTLINE(incorrect-equality): strict equality needed.
        require(
            exchangeBalanceAfter == exchangeBalanceBefore - amount,
            "INCORRECT_AMOUNT_TRANSFERRED"
        );
    }

    function transferOutMint(
        uint256 assetType,
        uint256 quantizedAmount,
        address recipient,
        bytes calldata mintingBlob
    ) internal override {
        // Make sure we don't accidentally burn funds.
        require(recipient != address(0x0), "INVALID_RECIPIENT");
        require(isMintableAssetType(assetType), "NON_MINTABLE_ASSET_TYPE");
        require(quantizedAmount > 0, "INVALID_MINT_AMOUNT");
        uint256 amount = fromQuantized(assetType, quantizedAmount);
        address tokenAddress = extractContractAddress(assetType);
        tokenAddress.safeTokenContractCall(
            abi.encodeWithSignature(
                "mintFor(address,uint256,bytes)",
                recipient,
                amount,
                mintingBlob
            )
        );
    }
}
