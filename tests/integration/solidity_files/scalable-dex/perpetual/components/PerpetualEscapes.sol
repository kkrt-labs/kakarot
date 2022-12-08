// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../libraries/LibConstants.sol";
import "../../interfaces/MAcceptModifications.sol";
import "../../interfaces/MFreezable.sol";
import "../../interfaces/IFactRegistry.sol";
import "./PerpetualStorage.sol";

/**
  Escaping the exchange is the last resort for users that wish to withdraw their funds without
  relying on off-chain exchange services. The Escape functionality may only be invoked once the
  contract has become frozen. This will be as the result of an unserviced forcedAction request
  At that point, any escaper entity may perform an escape operation as follows:

  1. Escapers call the :sol:mod:`PerpetualEscapeVerifier` contract with the Merkle proof for the vault to be evicted and the shared state. If the proof is valid, this results in the registration of said proof.
  2. Escapers call :sol:func:`escape` function with the starkKey, vaultId and quantizedAmount matching the proof from step 1.
  3. The owner of the vault may then withdraw this amount from the pending withdrawals account by calling the normal withdraw function (see :sol:mod:`Withdrawals`) to transfer the funds to the users ERC20 account.

  Note that while anyone can perform the initial steps of the escape operation (including the
  exchange operator, for example), only the owner of the vault may perform the final step of
  transferring the funds.
*/
abstract contract PerpetualEscapes is PerpetualStorage, MAcceptModifications, MFreezable {
    function initialize(address escapeVerifier) internal {
        escapeVerifierAddress = escapeVerifier;
    }

    /*
      Escape when the contract is frozen.
    */
    function escape(
        uint256 starkKey,
        uint256 vaultId,
        uint256 quantizedAmount
    ) external onlyFrozen {
        require(!escapesUsed[vaultId], "ESCAPE_ALREADY_USED");

        // Escape can be used only once.
        escapesUsed[vaultId] = true;
        escapesUsedCount += 1;

        bytes32 claimHash = keccak256(
            abi.encode(starkKey, quantizedAmount, sharedStateHash, vaultId)
        );
        IFactRegistry escapeVerifier = IFactRegistry(escapeVerifierAddress);
        require(escapeVerifier.isValid(claimHash), "ESCAPE_LACKS_PROOF");

        allowWithdrawal(starkKey, systemAssetType, quantizedAmount);
    }
}
