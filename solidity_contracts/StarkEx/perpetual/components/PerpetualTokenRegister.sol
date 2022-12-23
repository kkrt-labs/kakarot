// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../components/TokenRegister.sol";
import "./PerpetualStorage.sol";

/**
  Extension of the TokenRegister contract for StarkPerpetual.

  The change is that asset registration defines the system asset,
  and permitted only once.
*/
abstract contract PerpetualTokenRegister is PerpetualStorage, TokenRegister {
    event LogSystemAssetType(uint256 assetType);

    function registerToken(
        uint256, /* assetType */
        bytes calldata /* assetInfo */
    ) external override {
        revert("UNSUPPORTED_FUNCTION");
    }

    function registerToken(
        uint256, /* assetType */
        bytes memory, /* assetInfo */
        uint256 /* quantum */
    ) public override {
        revert("UNSUPPORTED_FUNCTION");
    }

    // NOLINTNEXTLINE external-function.
    function getSystemAssetType() public view returns (uint256) {
        return systemAssetType;
    }

    function registerSystemAssetType(uint256 assetType, bytes calldata assetInfo)
        external
        onlyTokensAdmin
    {
        require(systemAssetType == uint256(0), "SYSTEM_ASSET_TYPE_ALREADY_SET");
        systemAssetType = assetType;
        super.registerToken(assetType, assetInfo, 1);
        emit LogSystemAssetType(assetType);
    }
}
