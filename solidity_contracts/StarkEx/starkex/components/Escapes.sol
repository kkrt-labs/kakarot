// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../components/MainStorage.sol";
import "../../libraries/LibConstants.sol";
import "../../interfaces/MAcceptModifications.sol";
import "../../interfaces/MFreezable.sol";
import "../../interfaces/IFactRegistry.sol";
import "../../interfaces/MStateRoot.sol";

/**
  Escaping the exchange is the last resort for users that wish to withdraw their funds without
  relying on off-chain exchange services. The Escape functionality may only be invoked once the
  contract has become frozen. This will be as the result of an unserviced full withdraw request
  (see :sol:mod:`FullWithdrawals`). At that point, any escaper entity may perform an escape
  operation as follows:

  1. Escapers must obtain a Merkle path of a vault leaf to be evicted with respect to the frozen vault tree root. There are two vault trees: a validium vaults tree and a rollup vaults tree. Rollup vaults data can always be reconstructed from on-chain data. Typically, once the exchange is frozen, validium vaults data will be made public or would be obtainable from an exchange API, depending on the data availability approach used by the exchange.
  2. Escapers call the :sol:mod:`EscapeVerifier` contract with the Merkle proof for the vault to be evicted. The leaf index for the escape verifier can be computed from the vaultId by clearing the ROLLUP_VAULTS_BIT bit. If the proof is valid, this results in the registration of such proof.
  3. Escapers call :sol:func:`escape` function with the parameters that constituted the escapeProof submitted to the :sol:mod:`EscapeVerifier` (i.e. the Public Key of the vault owner, full vault ID, asset ID and vault balance). If a proof was accepted for those parameters by the :sol:mod:`EscapeVerifier`, and no prior escape call was made for the vault, the contract adds the vault balance to an on-chain pending withdrawals account under the Public Key of the vault owner and the appropriate asset ID.
  4. The owner of the vault may then withdraw this amount from the pending withdrawals account by calling the normal withdraw function (see :sol:mod:`Withdrawals`) to transfer the funds to the users Eth or ERC20 account (depending on the token type).

  Note that while anyone can perform the initial steps of the escape operation (including the
  exchange operator, for example), only the owner of the vault may perform the final step of
  transferring the funds.
*/
abstract contract Escapes is
    MainStorage,
    LibConstants,
    MAcceptModifications,
    MFreezable,
    MStateRoot
{
    function initialize(address escapeVerifier) internal {
        escapeVerifierAddress = escapeVerifier;
    }

    /*
      Escape when the contract is frozen.
    */
    function escape(
        uint256 ownerKey,
        uint256 vaultId,
        uint256 assetId,
        uint256 quantizedAmount
    ) external onlyFrozen {
        require(isVaultInRange(vaultId), "OUT_OF_RANGE_VAULT_ID");
        require(!escapesUsed[vaultId], "ESCAPE_ALREADY_USED");

        // Escape can be used only once.
        escapesUsed[vaultId] = true;
        escapesUsedCount += 1;

        // Select a vault tree to escape from, based on the vault id.
        (uint256 root, uint256 treeHeight) = isValidiumVault(vaultId)
            ? (getValidiumVaultRoot(), getValidiumTreeHeight())
            : (getRollupVaultRoot(), getRollupTreeHeight());

        // The index of vaultId leaf in its tree doesn't include the rollup bit flag.
        uint256 vaultLeafIndex = getVaultLeafIndex(vaultId);

        bytes32 claimHash = keccak256(
            abi.encode(ownerKey, assetId, quantizedAmount, root, treeHeight, vaultLeafIndex)
        );
        IFactRegistry escapeVerifier = IFactRegistry(escapeVerifierAddress);
        require(escapeVerifier.isValid(claimHash), "ESCAPE_LACKS_PROOF");

        allowWithdrawal(ownerKey, assetId, quantizedAmount);
    }
}
