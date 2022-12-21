// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interfaces/MApprovalChain.sol";
import "../libraries/LibConstants.sol";
import "./MainStorage.sol";

/**
  A Verifier contract is an implementation of a STARK verifier that the exchange service sends
  STARK proofs to. In addition, the exchange contract can call a verifier to check if a valid proof
  has been accepted for a given state transition (typically described as a hash on the public input
  of the assumed proof).

  The exchange contract will normally query only one verifier contract for proof validity checks.
  However, in the event that the verifier algorithm needs to updated, additional verifiers may be
  registered with the exchange contract by the contract :sol:mod:`MainGovernance`. Such new
  verifiers are then also be required to attest to the validity of state transitions and only if all
  the verifiers attest to the validity the state transition is accepted.

  Removal of verifiers is also the responsibility of the :sol:mod:`MainGovernance`. The removal
  process is more sensitive than verifier registration as it may affect the soundness of the system.
  Hence, this is performed in two steps:

  1. The :sol:mod:`MainGovernance` first announces the intent to remove a verifier by calling :sol:func:`announceVerifierRemovalIntent`
  2. After the expiration of a `VERIFIER_REMOVAL_DELAY` time lock, actual removal may be performed by calling :sol:func:`removeVerifier`

  The removal delay ensures that a user concerned about the soundness of the system has ample time
  to leave the exchange.
*/
abstract contract Verifiers is MainStorage, LibConstants, MApprovalChain {
    function getRegisteredVerifiers() external view returns (address[] memory _verifers) {
        return verifiersChain.list;
    }

    function isVerifier(address verifierAddress) external view returns (bool) {
        return findEntry(verifiersChain.list, verifierAddress) != ENTRY_NOT_FOUND;
    }

    function registerVerifier(address verifier, string calldata identifier) external {
        addEntry(verifiersChain, verifier, MAX_VERIFIER_COUNT, identifier);
    }

    function announceVerifierRemovalIntent(address verifier) external {
        announceRemovalIntent(verifiersChain, verifier, VERIFIER_REMOVAL_DELAY);
    }

    function removeVerifier(address verifier) external {
        removeEntry(verifiersChain, verifier);
    }
}
