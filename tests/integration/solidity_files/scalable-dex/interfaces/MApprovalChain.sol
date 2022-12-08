// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../libraries/Common.sol";

/*
  Implements a data structure that supports instant registration
  and slow time-locked removal of entries.
*/
abstract contract MApprovalChain {
    uint256 constant ENTRY_NOT_FOUND = uint256(~0);

    /*
      Adds the given verifier (entry) to the chain.
      Fails if the size of the chain is already >= maxLength.
      Fails if identifier is not identical to the value returned from entry.identify().
    */
    function addEntry(
        StarkExTypes.ApprovalChainData storage chain,
        address entry,
        uint256 maxLength,
        string memory identifier
    ) internal virtual;

    /*
      Returns the index of the verifier in the list if it exists and returns ENTRY_NOT_FOUND
      otherwise.
    */
    function findEntry(address[] storage list, address entry)
        internal
        view
        virtual
        returns (uint256);

    /*
      Same as findEntry(), except that it reverts if the verifier is not found.
    */
    function safeFindEntry(address[] storage list, address entry)
        internal
        view
        virtual
        returns (uint256 idx);

    /*
      Updates the unlockedForRemovalTime field of the given verifier to
        current time + removalDelay.
      Reverts if the verifier is not found.
    */
    function announceRemovalIntent(
        StarkExTypes.ApprovalChainData storage chain,
        address entry,
        uint256 removalDelay
    ) internal virtual;

    /*
      Removes a verifier assuming the expected time has passed.
    */
    function removeEntry(StarkExTypes.ApprovalChainData storage chain, address entry)
        internal
        virtual;
}
