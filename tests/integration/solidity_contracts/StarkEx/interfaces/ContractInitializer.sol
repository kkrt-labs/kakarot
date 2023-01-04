// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

/**
  Interface for contract initialization.
  The functions it exposes are the app specific parts of the contract initialization,
  and are called by the ProxySupport contract that implement the generic part of behind-proxy
  initialization.
*/
abstract contract ContractInitializer {
    function numOfSubContracts() internal pure virtual returns (uint256);

    function isInitialized() internal view virtual returns (bool);

    function validateInitData(bytes calldata data) internal pure virtual;

    function processSubContractAddresses(bytes calldata subContractAddresses) internal virtual;

    function initializeContractState(bytes calldata data) internal virtual;
}
