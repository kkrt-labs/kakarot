// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

/*
  Interface for a generic dispatcher to use, which the concrete dispatcher must implement.
  It contains the functions that are specific to the concrete dispatcher instance.
  The interface is implemented as contract, because interface implies all methods external.
*/
abstract contract IDispatcherBase {
    function getSubContract(bytes4 selector) public view virtual returns (address);

    function setSubContractAddress(uint256 index, address subContract) internal virtual;

    function getNumSubcontracts() internal pure virtual returns (uint256);

    function validateSubContractIndex(uint256 index, address subContract) internal pure virtual;

    /*
      Ensures initializer can be called. Reverts otherwise.
    */
    function initializationSentinel() internal view virtual;
}
