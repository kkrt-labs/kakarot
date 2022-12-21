// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../libraries/LibConstants.sol";
import "../interfaces/MGovernance.sol";
import "../interfaces/MTokenAssetData.sol";
import "../tokens/ERC20/IERC20.sol";
import "./MainStorage.sol";

/**
  Registration of a new token (:sol:func:`registerToken`) entails defining a new asset type within
  the system, and associating it with an `assetInfo` array of
  bytes and a quantization factor (`quantum`).

  The `assetInfo` is a byte array, with a size depending on the token.
  For ETH, assetInfo is 4 bytes long. For ERC20 tokens, it is 36 bytes long.

  For each token type, the following constant 4-byte hash is defined, called the `selector`:

   | `ETH_SELECTOR = bytes4(keccak256("ETH()"));`
   | `ERC20_SELECTOR = bytes4(keccak256("ERC20Token(address)"));`
   | `ERC721_SELECTOR = bytes4(keccak256("ERC721Token(address,uint256)"));`
   | `MINTABLE_ERC20_SELECTOR = bytes4(keccak256("MintableERC20Token(address)"));`
   | `MINTABLE_ERC721_SELECTOR = bytes4(keccak256("MintableERC721Token(address,uint256)"));`

  For each token type, `assetInfo` is defined as follows:


  The `quantum` quantization factor defines the multiplicative transformation from the native token
  denomination as a 256b unsigned integer to a 63b unsigned integer representation as used by the
  Stark exchange. Only amounts in the native representation that represent an integer number of
  quanta are allowed in the system.

  The asset type is restricted to be the result of a hash of the `assetInfo` and the
  `quantum` masked to 250 bits (to be less than the prime used) according to the following formula:

  | ``uint256 assetType = uint256(keccak256(abi.encodePacked(assetInfo, quantum))) &``
  | ``0x03FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;``

  Once registered, tokens cannot be removed from the system, as their IDs may be used by off-chain
  accounts.

  New tokens may only be registered by a Token Administrator. A Token Administrator may be instantly
  appointed or removed by the contract Governor (see :sol:mod:`MainGovernance`). Typically, the
  Token Administrator's private key should be kept in a cold wallet.
*/
abstract contract TokenRegister is MainStorage, LibConstants, MGovernance, MTokenAssetData {
    event LogTokenRegistered(uint256 assetType, bytes assetInfo, uint256 quantum);
    event LogTokenAdminAdded(address tokenAdmin);
    event LogTokenAdminRemoved(address tokenAdmin);

    modifier onlyTokensAdmin() {
        require(isTokenAdmin(msg.sender), "ONLY_TOKENS_ADMIN");
        _;
    }

    function isTokenAdmin(address testedAdmin) public view returns (bool) {
        return tokenAdmins[testedAdmin];
    }

    function registerTokenAdmin(address newAdmin) external onlyGovernance {
        tokenAdmins[newAdmin] = true;
        emit LogTokenAdminAdded(newAdmin);
    }

    function unregisterTokenAdmin(address oldAdmin) external onlyGovernance {
        tokenAdmins[oldAdmin] = false;
        emit LogTokenAdminRemoved(oldAdmin);
    }

    function isAssetRegistered(uint256 assetType) public view returns (bool) {
        return registeredAssetType[assetType];
    }

    /*
      Registers a new asset to the system.
      Once added, it can not be removed and there is a limited number
      of slots available.
    */
    function registerToken(
        uint256 assetType,
        bytes calldata assetInfo,
        uint256 quantum
    ) public virtual onlyTokensAdmin {
        // Make sure it is not invalid or already registered.
        require(!isAssetRegistered(assetType), "ASSET_ALREADY_REGISTERED");
        require(assetType < K_MODULUS, "INVALID_ASSET_TYPE");
        require(quantum > 0, "INVALID_QUANTUM");
        require(quantum < QUANTUM_UPPER_BOUND, "INVALID_QUANTUM");

        // Require that the assetType is the hash of the assetInfo and quantum truncated to 250 bits.
        uint256 enforcedId = uint256(keccak256(abi.encodePacked(assetInfo, quantum))) & MASK_250;
        require(assetType == enforcedId, "INVALID_ASSET_TYPE");

        verifyAssetInfo(assetInfo);
        // NFTs quantum must equal one.
        if (isNonFungibleAssetInfo(assetInfo)) {
            require(quantum == 1, "INVALID_NFT_QUANTUM");
        }

        // Add token to the in-storage structures.
        registeredAssetType[assetType] = true;
        assetTypeToAssetInfo[assetType] = assetInfo;
        assetTypeToQuantum[assetType] = quantum;

        // Log the registration of a new token.
        emit LogTokenRegistered(assetType, assetInfo, quantum);
    }

    function registerToken(uint256 assetType, bytes calldata assetInfo) external virtual {
        registerToken(assetType, assetInfo, 1);
    }
}
