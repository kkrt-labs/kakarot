// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../interfaces/ExternalInitializer.sol";
import "../../interfaces/Identity.sol";
import "../../interfaces/IFactRegistry.sol";
import "../../components/MainStorage.sol";
import "../../libraries/Common.sol";
import "../../libraries/LibConstants.sol";

/*
  This contract is an external initializing contract that replaces the escape verifier used by
  the main contract.
*/
contract ReplaceEscapeVerifierExternalInitializer is
    ExternalInitializer,
    MainStorage,
    LibConstants
{
    using Addresses for address;

    /*
      The initiatialize function gets two parameters in the bytes array:
      1. New escape verifier address,
      2. Keccak256 of the expected id of the contract provied in (1).
    */
    function initialize(bytes calldata data) external override {
        require(data.length == 64, "UNEXPECTED_DATA_SIZE");

        // Extract sub-contract address and hash of verifierId.
        (address newEscapeVerifierAddress, bytes32 escapeVerifierIdHash) = abi.decode(
            data,
            (address, bytes32)
        );

        require(newEscapeVerifierAddress.isContract(), "ADDRESS_NOT_CONTRACT");
        bytes32 contractIdHash = keccak256(
            abi.encodePacked(Identity(newEscapeVerifierAddress).identify())
        );
        require(contractIdHash == escapeVerifierIdHash, "UNEXPECTED_CONTRACT_IDENTIFIER");

        // Replace the escape verifier address in storage.
        escapeVerifierAddress = newEscapeVerifierAddress;

        emit LogExternalInitialize(data);
    }
}
