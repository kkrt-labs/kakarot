// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../interfaces/ExternalInitializer.sol";
import "../../interfaces/Identity.sol";
import "../../libraries/Common.sol";
import "../../libraries/LibConstants.sol";
import "../../components/MainStorage.sol";

/*
  This contract is an external initializing contract that performs required adjustments for V3->V4.5
  ugrade:
  1. Replace verifier adapter.
  2. Set migrated order tree root and height.
  3. Set new rollup tree root and height.
  4. set new globalConfigCode value.

  Note: The values stored in vaultRoot and vaultTreeHeight are unchanged in the upgrade to V4.5.
  These storage slots are renamed validiumVaultRoot and validiumTreeHeight.
*/
contract V3toV45ChangesExternalInitializer is ExternalInitializer, MainStorage, LibConstants {
    using Addresses for address;
    uint256 constant ENTRY_NOT_FOUND = uint256(~0);

    event OrderTreeMigration(
        uint256 oldOrderRoot,
        uint256 oldOrderTreeHeight,
        uint256 newOrderRoot,
        uint256 newOrderTreeHeight
    );

    function initialize(bytes calldata data) external override {
        require(data.length == 224, "INCORRECT_INIT_DATA_SIZE_224");
        (
            address newVerifierAddress,
            bytes32 verifierIdHash,
            uint256 newOrderRoot,
            uint256 newOrderTreeHeight,
            uint256 newRollupVaultRoot,
            uint256 newRollupTreeHeigh,
            uint256 newGlobalConfigCode
        ) = abi.decode(data, (address, bytes32, uint256, uint256, uint256, uint256, uint256));

        require(newGlobalConfigCode < K_MODULUS, "GLOBAL_CONFIG_CODE >= PRIME");
        require(newRollupTreeHeigh < ROLLUP_VAULTS_BIT, "INVALID_ROLLUP_HEIGHT");

        // Flush the current verifiers & availabilityVerifier list.
        delete verifiersChain.list;

        // ApprovalChain addEntry performs all the required checks for us.
        addEntry(verifiersChain, newVerifierAddress, MAX_VERIFIER_COUNT, verifierIdHash);

        uint256 oldOrderRoot = orderRoot;
        uint256 oldOrderTreeHeight = orderTreeHeight;

        orderRoot = newOrderRoot;
        orderTreeHeight = newOrderTreeHeight;
        rollupVaultRoot = newRollupVaultRoot;
        rollupTreeHeight = newRollupTreeHeigh;
        globalConfigCode = newGlobalConfigCode;

        emit OrderTreeMigration(oldOrderRoot, oldOrderTreeHeight, newOrderRoot, newOrderTreeHeight);
        emit LogExternalInitialize(data);
    }

    /*
      The two functions below are taken from ApprovalChain.sol, with minor changes:
      1. No governance needed (we are under the context where proxy governance is granted).
      2. The verifier ID is passed as hash, and not as string.
    */
    function addEntry(
        StarkExTypes.ApprovalChainData storage chain,
        address entry,
        uint256 maxLength,
        bytes32 hashExpectedId
    ) internal {
        address[] storage list = chain.list;
        require(entry.isContract(), "ADDRESS_NOT_CONTRACT");
        bytes32 hashRealId = keccak256(abi.encodePacked(Identity(entry).identify()));
        require(hashRealId == hashExpectedId, "UNEXPECTED_CONTRACT_IDENTIFIER");
        require(list.length < maxLength, "CHAIN_AT_MAX_CAPACITY");
        require(findEntry(list, entry) == ENTRY_NOT_FOUND, "ENTRY_ALREADY_EXISTS");
        chain.list.push(entry); // NOLINT controlled-array-length;
        chain.unlockedForRemovalTime[entry] = 0;
    }

    function findEntry(address[] storage list, address entry) internal view returns (uint256) {
        uint256 n_entries = list.length;
        for (uint256 i = 0; i < n_entries; i++) {
            if (list[i] == entry) {
                return i;
            }
        }
        return ENTRY_NOT_FOUND;
    }
}
