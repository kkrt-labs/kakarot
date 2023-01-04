// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

abstract contract MTokenTransfers {
    function transferIn(uint256 assetType, uint256 quantizedAmount) internal virtual;

    function transferInWithTokenId(
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) internal virtual;

    function transferOut(
        address payable recipient,
        uint256 assetType,
        uint256 quantizedAmount
    ) internal virtual;

    function transferOutWithTokenId(
        address recipient,
        uint256 assetType,
        uint256 tokenId,
        uint256 quantizedAmount
    ) internal virtual;

    function transferOutMint(
        uint256 assetType,
        uint256 quantizedAmount,
        address recipient,
        bytes calldata mintingBlob
    ) internal virtual;
}
