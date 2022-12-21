// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../interfaces/ExternalInitializer.sol";
import "../../interfaces/Identity.sol";
import "../../components/MainStorage.sol";
import "../../libraries/Common.sol";
import "../../libraries/LibConstants.sol";

/*
  This contract is a simple implementation of an external initializing contract
  that removes all existing verifiers and committees and install the ones provided in parameters.
*/
contract ChangeVerifiersExternalInitializer is ExternalInitializer, MainStorage, LibConstants {
    using Addresses for address;
    uint256 constant ENTRY_NOT_FOUND = uint256(~0);

    /*
      The initiatialize function gets four parameters in the bytes array:
      1. New verifier address,
      2. Keccak256 of the expected verifier id.
      3. New availability verifier address,
      4. Keccak256 of the expected availability verifier id.
    */
    function initialize(bytes calldata data) public virtual override {
        require(data.length == 128, "UNEXPECTED_DATA_SIZE");
        address newVerifierAddress;
        bytes32 verifierIdHash;
        address newAvailabilityVerifierAddress;
        bytes32 availabilityVerifierIdHash;

        // Extract sub-contract address and hash of verifierId.
        (
            newVerifierAddress,
            verifierIdHash,
            newAvailabilityVerifierAddress,
            availabilityVerifierIdHash
        ) = abi.decode(data, (address, bytes32, address, bytes32));

        // Flush the entire verifiers list.
        delete verifiersChain.list;
        delete availabilityVerifiersChain.list;

        // ApprovalChain addEntry performs all the required checks for us.
        addEntry(verifiersChain, newVerifierAddress, MAX_VERIFIER_COUNT, verifierIdHash);
        addEntry(
            availabilityVerifiersChain,
            newAvailabilityVerifierAddress,
            MAX_VERIFIER_COUNT,
            availabilityVerifierIdHash
        );

        emit LogExternalInitialize(data);
    }

    /*
      The functions below are taken from ApprovalChain.sol, with minor changes:
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
