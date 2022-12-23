// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../PerpetualConstants.sol";
import "../components/PerpetualStorage.sol";
import "../../interfaces/MGovernance.sol";

/**
  Configuration contract facilitates storing system configuration hashes.
  A configuration item hash can be stored only once, and cannot be altered or removed.

  If there is a need for a configuration change (not addition of new one),
  it shall be performed via upgrade using a dedicated External Initializing Contract (EIC).
*/
abstract contract Configuration is PerpetualStorage, PerpetualConstants, MGovernance {
    // This key is used in for the actionsTimeLock.
    uint256 constant GLOBAL_CONFIG_KEY = uint256(~0);

    event LogGlobalConfigurationRegistered(bytes32 configHash);
    event LogGlobalConfigurationApplied(bytes32 configHash);
    event LogGlobalConfigurationRemoved(bytes32 configHash);
    event LogAssetConfigurationRegistered(uint256 assetId, bytes32 configHash);
    event LogAssetConfigurationApplied(uint256 assetId, bytes32 configHash);
    event LogAssetConfigurationRemoved(uint256 assetId, bytes32 configHash);

    /*
      Configuration delay is set during initialization.
      It is designed to be changed only through upgrade cycle, by altering the storage variable.
    */
    function initialize(uint256 delay) internal {
        configurationDelay = delay;
    }

    /*
      Register global configuration hash, for applying once configuration delay time-lock expires.
    */
    function registerGlobalConfigurationChange(bytes32 configHash) external onlyGovernance {
        require(uint256(configHash) < K_MODULUS, "INVALID_CONFIG_HASH");
        bytes32 actionKey = keccak256(abi.encodePacked(GLOBAL_CONFIG_KEY, configHash));

        actionsTimeLock[actionKey] = block.timestamp + configurationDelay;
        emit LogGlobalConfigurationRegistered(configHash);
    }

    /*
      Applies global configuration hash.
    */
    function applyGlobalConfigurationChange(bytes32 configHash) external onlyGovernance {
        bytes32 actionKey = keccak256(abi.encode(GLOBAL_CONFIG_KEY, configHash));
        uint256 activationTime = actionsTimeLock[actionKey];
        require(activationTime > 0, "CONFIGURATION_NOT_REGSITERED");
        require(activationTime <= block.timestamp, "CONFIGURATION_NOT_ENABLE_YET");
        globalConfigurationHash = configHash;
        emit LogGlobalConfigurationApplied(configHash);
    }

    function removeGlobalConfigurationChange(bytes32 configHash) external onlyGovernance {
        bytes32 actionKey = keccak256(abi.encodePacked(GLOBAL_CONFIG_KEY, configHash));
        require(actionsTimeLock[actionKey] > 0, "CONFIGURATION_NOT_REGSITERED");
        delete actionsTimeLock[actionKey];
        emit LogGlobalConfigurationRemoved(configHash);
    }

    /*
      Register an asset configuration hash, for applying once configuration delay time-lock expires.
    */
    function registerAssetConfigurationChange(uint256 assetId, bytes32 configHash)
        external
        onlyGovernance
    {
        require(assetId < PERPETUAL_ASSET_ID_UPPER_BOUND, "INVALID_ASSET_ID");
        require(uint256(configHash) < K_MODULUS, "INVALID_CONFIG_HASH");
        bytes32 actionKey = keccak256(abi.encode(assetId, configHash));
        actionsTimeLock[actionKey] = block.timestamp + configurationDelay;
        emit LogAssetConfigurationRegistered(assetId, configHash);
    }

    /*
      Applies asset configuration hash.
    */
    function applyAssetConfigurationChange(uint256 assetId, bytes32 configHash)
        external
        onlyGovernance
    {
        bytes32 actionKey = keccak256(abi.encode(assetId, configHash));
        uint256 activationTime = actionsTimeLock[actionKey];
        require(activationTime > 0, "CONFIGURATION_NOT_REGSITERED");
        require(activationTime <= block.timestamp, "CONFIGURATION_NOT_ENABLE_YET");
        configurationHash[assetId] = configHash;
        emit LogAssetConfigurationApplied(assetId, configHash);
    }

    function removeAssetConfigurationChange(uint256 assetId, bytes32 configHash)
        external
        onlyGovernance
    {
        bytes32 actionKey = keccak256(abi.encode(assetId, configHash));
        require(actionsTimeLock[actionKey] > 0, "CONFIGURATION_NOT_REGSITERED");
        delete actionsTimeLock[actionKey];
        emit LogAssetConfigurationRemoved(assetId, configHash);
    }
}
