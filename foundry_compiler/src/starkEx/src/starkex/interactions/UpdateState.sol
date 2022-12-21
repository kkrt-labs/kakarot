// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../components/StarkExStorage.sol";
import "../interfaces/MStarkExForcedActionState.sol";
import "../PublicInputOffsets.sol";
import "../StarkExConstants.sol";
import "../../components/MessageRegistry.sol";
import "../../components/OnchainDataFactTreeEncoder.sol";
import "../../components/VerifyFactChain.sol";
import "../../interfaces/MAcceptModifications.sol";
import "../../interfaces/MFreezable.sol";
import "../../interfaces/MOperator.sol";
import "../../libraries/Common.sol";

/**
  The StarkEx contract tracks the state of the off-chain exchange service by storing Merkle roots
  of the vault state (off-chain account state) and the order state (including fully executed and
  partially fulfilled orders).

  The :sol:mod:`Operator` is the only entity entitled to submit state updates for a batch of
  exchange transactions by calling :sol:func:`updateState` and this is only allowed if the contract
  is not in the `frozen` state (see :sol:mod:`FullWithdrawals`). The call includes the `publicInput`
  of a STARK proof, and additional data (`applicationData`) that includes information not attested
  to by the proof.

  The `publicInput` includes the current (initial) and next (final) Merkle roots as mentioned above,
  the heights of the Merkle trees, a list of vault operations and a list of conditional transfers.

  A vault operation can be a ramping operation (deposit/withdrawal) or an indication to clear
  a full withdrawal request. Each vault operation is encoded in 3 words as follows:
  | 1. Word 0: Stark Key of the vault owner (or the requestor Stark Key for false full
  |    withdrawal).
  | 2. Word 1: Asset ID of the vault representing either the currency (for fungible tokens) or
  |    a unique token ID and its on-chain contract association (for non-fungible tokens).
  | 3. Word 2:
  |    a. ID of the vault (off-chain account)
  |    b. Vault balance change in biased representation (excess-2**63).
  |       A negative balance change implies a withdrawal while a positive amount implies a deposit.
  |       A zero balance change may be used for operations implying neither
  |       (e.g. a false full withdrawal request).
  |    c. A bit indicating whether the operation requires clearing a full withdrawal request.

  The above information is used by the exchange contract in order to update the pending accounts
  used for deposits (see :sol:mod:`Deposits`) and withdrawals (see :sol:mod:`Withdrawals`).

  The next section in the publicInput is a list of encoded conditions corresponding to the
  conditional transfers in the batch. A condition is encoded as a hash of the conditional transfer
  `applicationData`, described below, masked to 250 bits.

  The `applicationData` holds the following information:
  | 1. The ID of the current batch for which the operator is submitting the update.
  | 2. The expected ID of the last batch accepted on chain. This allows the operator submitting
  |    state updates to ensure the same batch order is accepted on-chain as was intended by the
  |    operator in the event that more than one valid update may have been generated based on
  |    different previous batches - an unlikely but possible event.
  | 3. For each conditional transfer in the batch two words are provided:
  |    a. Word 0: The address of a fact registry contract
  |    b. Word 1: A fact to be verified on the above contract attesting that the
  |       condition has been met on-chain.


  The following section in the publicInput is a list of orders to be verified onchain, corresponding
  to the onchain orders in the batch. An onchain order is of a variable length (at least 3 words)
  and is structured as follows:
  | 1. The Eth address of the user who submitted the order.
  | 2. The size (number of words) of the order blob that follows. Denoted 'n' below.
  | 3. First word of the order blob.
  | ...
  | n + 2. Last word of the order blob.

  The STARK proof attesting to the validity of the state update is submitted separately by the
  exchange service to (one or more) STARK integrity verifier contract(s).
  Likewise, the signatures of committee members attesting to
  the availability of the vault and order data is submitted separately by the exchange service to
  (one or more) availability verifier contract(s) (see :sol:mod:`Committee`).

  The state update is only accepted by the exchange contract if the integrity verifier and
  availability verifier contracts have indeed received such proof of soundness and data
  availability.
*/
abstract contract UpdateState is
    StarkExStorage,
    StarkExConstants,
    MStarkExForcedActionState,
    VerifyFactChain,
    MAcceptModifications,
    MFreezable,
    MOperator,
    PublicInputOffsets
{
    event LogRootUpdate(
        uint256 sequenceNumber,
        uint256 batchId,
        uint256 validiumVaultRoot,
        uint256 rollupVaultRoot,
        uint256 orderRoot
    );

    event LogStateTransitionFact(bytes32 stateTransitionFact);

    event LogVaultBalanceChangeApplied(
        address ethKey,
        uint256 assetId,
        uint256 vaultId,
        int256 quantizedAmountChange
    );

    function updateState(uint256[] calldata publicInput, uint256[] calldata applicationData)
        external
        virtual
        notFrozen
        onlyOperator
    {
        require(
            publicInput.length >= PUB_IN_TRANSACTIONS_DATA_OFFSET,
            "publicInput does not contain all required fields."
        );
        require(
            publicInput[PUB_IN_GLOBAL_CONFIG_CODE_OFFSET] == globalConfigCode,
            "Global config code mismatch."
        );
        require(
            publicInput[PUB_IN_FINAL_VALIDIUM_VAULT_ROOT_OFFSET] < K_MODULUS,
            "New validium vault root >= PRIME."
        );
        require(
            publicInput[PUB_IN_FINAL_ROLLUP_VAULT_ROOT_OFFSET] < K_MODULUS,
            "New rollup vault root >= PRIME."
        );
        require(
            publicInput[PUB_IN_FINAL_ORDER_ROOT_OFFSET] < K_MODULUS,
            "New order root >= PRIME."
        );
        require(
            lastBatchId == 0 || applicationData[APP_DATA_PREVIOUS_BATCH_ID_OFFSET] == lastBatchId,
            "WRONG_PREVIOUS_BATCH_ID"
        );

        // Ensure global timestamp has not expired.
        require(
            publicInput[PUB_IN_GLOBAL_EXPIRATION_TIMESTAMP_OFFSET] <
                2**STARKEX_EXPIRATION_TIMESTAMP_BITS,
            "Global expiration timestamp is out of range."
        );

        require( // NOLINT: block-timestamp.
            publicInput[PUB_IN_GLOBAL_EXPIRATION_TIMESTAMP_OFFSET] > block.timestamp / 3600,
            "Timestamp of the current block passed the threshold for the transaction batch."
        );

        bytes32 stateTransitionFact = getStateTransitionFact(publicInput);

        emit LogStateTransitionFact(stateTransitionFact);

        verifyFact(
            verifiersChain,
            stateTransitionFact,
            "NO_STATE_TRANSITION_VERIFIERS",
            "NO_STATE_TRANSITION_PROOF"
        );

        bytes32 availabilityFact = keccak256(
            abi.encodePacked(
                publicInput[PUB_IN_FINAL_VALIDIUM_VAULT_ROOT_OFFSET],
                publicInput[PUB_IN_VALIDIUM_VAULT_TREE_HEIGHT_OFFSET],
                publicInput[PUB_IN_FINAL_ORDER_ROOT_OFFSET],
                publicInput[PUB_IN_ORDER_TREE_HEIGHT_OFFSET],
                sequenceNumber + 1
            )
        );

        verifyFact(
            availabilityVerifiersChain,
            availabilityFact,
            "NO_AVAILABILITY_VERIFIERS",
            "NO_AVAILABILITY_PROOF"
        );

        performUpdateState(publicInput, applicationData);
    }

    function getStateTransitionFact(uint256[] calldata publicInput)
        internal
        pure
        returns (bytes32)
    {
        // Use a simple fact tree.
        require(
            publicInput.length >=
                PUB_IN_TRANSACTIONS_DATA_OFFSET +
                    OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS,
            "programOutput does not contain all required fields."
        );
        return
            OnchainDataFactTreeEncoder.encodeFactWithOnchainData(
                publicInput[:publicInput.length -
                    OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS],
                OnchainDataFactTreeEncoder.DataAvailabilityFact({
                    onchainDataHash: publicInput[publicInput.length - 2],
                    onchainDataSize: publicInput[publicInput.length - 1]
                })
            );
    }

    function performUpdateState(uint256[] calldata publicInput, uint256[] calldata applicationData)
        internal
    {
        rootUpdate(
            publicInput[PUB_IN_INITIAL_VALIDIUM_VAULT_ROOT_OFFSET],
            publicInput[PUB_IN_FINAL_VALIDIUM_VAULT_ROOT_OFFSET],
            publicInput[PUB_IN_INITIAL_ROLLUP_VAULT_ROOT_OFFSET],
            publicInput[PUB_IN_FINAL_ROLLUP_VAULT_ROOT_OFFSET],
            publicInput[PUB_IN_INITIAL_ORDER_ROOT_OFFSET],
            publicInput[PUB_IN_FINAL_ORDER_ROOT_OFFSET],
            publicInput[PUB_IN_VALIDIUM_VAULT_TREE_HEIGHT_OFFSET],
            publicInput[PUB_IN_ROLLUP_VAULT_TREE_HEIGHT_OFFSET],
            publicInput[PUB_IN_ORDER_TREE_HEIGHT_OFFSET],
            applicationData[APP_DATA_BATCH_ID_OFFSET]
        );
        performOnchainOperations(publicInput, applicationData);
    }

    function rootUpdate(
        uint256 oldValidiumVaultRoot,
        uint256 newValidiumVaultRoot,
        uint256 oldRollupVaultRoot,
        uint256 newRollupVaultRoot,
        uint256 oldOrderRoot,
        uint256 newOrderRoot,
        uint256 validiumTreeHeightSent,
        uint256 rollupTreeHeightSent,
        uint256 orderTreeHeightSent,
        uint256 batchId
    ) internal virtual {
        // Assert that the old state is correct.
        require(oldValidiumVaultRoot == validiumVaultRoot, "VALIDIUM_VAULT_ROOT_INCORRECT");
        require(oldRollupVaultRoot == rollupVaultRoot, "ROLLUP_VAULT_ROOT_INCORRECT");
        require(oldOrderRoot == orderRoot, "ORDER_ROOT_INCORRECT");

        // Assert that heights are correct.
        require(validiumTreeHeight == validiumTreeHeightSent, "VALIDIUM_TREE_HEIGHT_INCORRECT");
        require(rollupTreeHeight == rollupTreeHeightSent, "ROLLUP_TREE_HEIGHT_INCORRECT");
        require(orderTreeHeight == orderTreeHeightSent, "ORDER_TREE_HEIGHT_INCORRECT");

        // Update state.
        validiumVaultRoot = newValidiumVaultRoot;
        rollupVaultRoot = newRollupVaultRoot;
        orderRoot = newOrderRoot;
        sequenceNumber = sequenceNumber + 1;
        lastBatchId = batchId;

        // Log update.
        emit LogRootUpdate(sequenceNumber, batchId, validiumVaultRoot, rollupVaultRoot, orderRoot);
    }

    function performOnchainOperations(
        uint256[] calldata publicInput,
        uint256[] calldata applicationData
    ) private {
        uint256 nModifications = publicInput[PUB_IN_N_MODIFICATIONS_OFFSET];
        uint256 nCondTransfers = publicInput[PUB_IN_N_CONDITIONAL_TRANSFERS_OFFSET];
        uint256 nOnchainVaultUpdates = publicInput[PUB_IN_N_ONCHAIN_VAULT_UPDATES_OFFSET];
        uint256 nOnchainOrders = publicInput[PUB_IN_N_ONCHAIN_ORDERS_OFFSET];

        // Sanity value that also protects from theoretical overflow in multiplication.
        require(nModifications < 2**64, "Invalid number of modifications.");
        require(nCondTransfers < 2**64, "Invalid number of conditional transfers.");
        require(nOnchainVaultUpdates < 2**64, "Invalid number of onchain vault updates.");
        require(nOnchainOrders < 2**64, "Invalid number of onchain orders.");
        require(
            publicInput.length >=
                PUB_IN_TRANSACTIONS_DATA_OFFSET +
                    PUB_IN_N_WORDS_PER_MODIFICATION *
                    nModifications +
                    PUB_IN_N_WORDS_PER_CONDITIONAL_TRANSFER *
                    nCondTransfers +
                    PUB_IN_N_WORDS_PER_ONCHAIN_VAULT_UPDATE *
                    nOnchainVaultUpdates +
                    PUB_IN_N_MIN_WORDS_PER_ONCHAIN_ORDER *
                    nOnchainOrders +
                    OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS,
            "publicInput size is inconsistent with expected transactions."
        );
        require(
            applicationData.length ==
                APP_DATA_TRANSACTIONS_DATA_OFFSET +
                    APP_DATA_N_WORDS_PER_CONDITIONAL_TRANSFER *
                    nCondTransfers,
            "applicationData size is inconsistent with expected transactions."
        );

        uint256 offsetPubInput = PUB_IN_TRANSACTIONS_DATA_OFFSET;
        uint256 offsetAppData = APP_DATA_TRANSACTIONS_DATA_OFFSET;

        // When reaching this line, offsetPubInput is initialized to the beginning of modifications
        // data in publicInput. Following this line's execution, offsetPubInput is incremented by
        // the number of words consumed by sendModifications.
        offsetPubInput += sendModifications(publicInput[offsetPubInput:], nModifications);

        // When reaching this line, offsetPubInput and offsetAppData are pointing to the beginning
        // of conditional transfers data in publicInput and applicationData.
        // Following the execution of this block, offsetPubInput and offsetAppData are incremented
        // by the number of words consumed by verifyConditionalTransfers.
        {
            uint256 consumedPubInputWords;
            uint256 consumedAppDataWords;
            (consumedPubInputWords, consumedAppDataWords) = verifyConditionalTransfers(
                publicInput[offsetPubInput:],
                applicationData[offsetAppData:],
                nCondTransfers
            );

            offsetPubInput += consumedPubInputWords;
            offsetAppData += consumedAppDataWords;
        }

        // offsetPubInput is incremented by the number of words consumed by updateOnchainVaults.
        // NOLINTNEXTLINE: reentrancy-benign.
        offsetPubInput += updateOnchainVaults(publicInput[offsetPubInput:], nOnchainVaultUpdates);

        // offsetPubInput is incremented by the number of words consumed by verifyOnchainOrders.
        offsetPubInput += verifyOnchainOrders(publicInput[offsetPubInput:], nOnchainOrders);

        // The Onchain Data info appears at the end of publicInput.
        offsetPubInput += OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS;

        require(offsetPubInput == publicInput.length, "Incorrect Size");
    }

    /*
      Deposits and withdrawals. Moves funds off and on chain.
        slidingPublicInput - a pointer to the beginning of modifications data in publicInput.
        nModifications - the number of modifications.
      Returns the number of publicInput words consumed by this function.
    */
    function sendModifications(uint256[] calldata slidingPublicInput, uint256 nModifications)
        private
        returns (uint256 consumedPubInputItems)
    {
        uint256 offsetPubInput = 0;

        for (uint256 i = 0; i < nModifications; i++) {
            uint256 ownerKey = slidingPublicInput[offsetPubInput];
            uint256 assetId = slidingPublicInput[offsetPubInput + 1];

            require(ownerKey < K_MODULUS, "Stark key >= PRIME");
            require(assetId < K_MODULUS, "Asset id >= PRIME");

            uint256 actionParams = slidingPublicInput[offsetPubInput + 2];
            require((actionParams >> 129) == 0, "Unsupported modification action field.");

            // Extract and unbias the balanceDiff.
            int256 balanceDiff = int256((actionParams & ((1 << 64) - 1)) - (1 << 63));
            uint256 vaultId = (actionParams >> 64) & ((1 << 64) - 1);

            if (balanceDiff > 0) {
                // This is a deposit.
                acceptDeposit(ownerKey, vaultId, assetId, uint256(balanceDiff));
            } else if (balanceDiff < 0) {
                // This is a withdrawal.
                acceptWithdrawal(ownerKey, assetId, uint256(-balanceDiff));
            }

            if ((actionParams & (1 << 128)) != 0) {
                clearFullWithdrawalRequest(ownerKey, vaultId);
            }

            offsetPubInput += PUB_IN_N_WORDS_PER_MODIFICATION;
        }
        return offsetPubInput;
    }

    /*
      Verifies that each conditional transfer's condition was met.
        slidingPublicInput - a pointer to the beginning of condTransfers data in publicInput.
        slidingAppData - a pointer to the beginning of condTransfers data in applicationData.
        nCondTransfers - the number of conditional transfers.
      Returns the number of publicInput and applicationData words consumed by this function.
    */
    function verifyConditionalTransfers(
        uint256[] calldata slidingPublicInput,
        uint256[] calldata slidingAppData,
        uint256 nCondTransfers
    ) private view returns (uint256 consumedPubInputItems, uint256 consumedAppDataItems) {
        uint256 offsetPubInput = 0;
        uint256 offsetAppData = 0;

        for (uint256 i = 0; i < nCondTransfers; i++) {
            address factRegistryAddress = address(slidingAppData[offsetAppData]);
            bytes32 condTransferFact = bytes32(slidingAppData[offsetAppData + 1]);
            uint256 condition = slidingPublicInput[offsetPubInput];

            // The condition is the 250 LS bits of keccak256 of the fact registry & fact.
            require(
                condition ==
                    uint256(keccak256(abi.encodePacked(factRegistryAddress, condTransferFact))) &
                        MASK_250,
                "Condition mismatch."
            );
            // NOLINTNEXTLINE: low-level-calls-loop.
            (bool success, bytes memory returndata) = factRegistryAddress.staticcall(
                abi.encodeWithSignature("isValid(bytes32)", condTransferFact)
            );
            require(success && returndata.length == 32, "BAD_FACT_REGISTRY_CONTRACT");
            require(
                abi.decode(returndata, (bool)),
                "Condition for the conditional transfer was not met."
            );

            offsetPubInput += PUB_IN_N_WORDS_PER_CONDITIONAL_TRANSFER;
            offsetAppData += APP_DATA_N_WORDS_PER_CONDITIONAL_TRANSFER;
        }
        return (offsetPubInput, offsetAppData);
    }

    /*
      Moves funds into and out of onchain vaults.
        slidingPublicInput - a pointer to the beginning of onchain vaults update data in publicInput.
        nOnchainVaultUpdates - the number of onchain vaults updates.
      Returns the number of publicInput words consumed by this function.
    */
    function updateOnchainVaults(
        uint256[] calldata slidingPublicInput,
        uint256 nOnchainVaultUpdates
    ) private returns (uint256 consumedPubInputItems) {
        uint256 offsetPubInput = 0;

        for (uint256 i = 0; i < nOnchainVaultUpdates; i++) {
            address ethAddress = address(slidingPublicInput[offsetPubInput]);
            uint256 assetId = slidingPublicInput[offsetPubInput + 1];

            require(assetId < K_MODULUS, "assetId >= PRIME");

            uint256 additionalParams = slidingPublicInput[offsetPubInput + 2];
            require((additionalParams >> 160) == 0, "Unsupported vault update field.");

            // Extract and unbias the balanceDiff.
            int256 balanceDiff = int256((additionalParams & ((1 << 64) - 1)) - (1 << 63));

            int256 minBalance = int256((additionalParams >> 64) & ((1 << 64) - 1));
            uint256 vaultId = (additionalParams >> 128) & ((1 << 31) - 1);

            int256 balanceBefore = int256(vaultsBalances[ethAddress][assetId][vaultId]);
            int256 newBalance = balanceBefore + balanceDiff;

            if (balanceDiff > 0) {
                require(newBalance > balanceBefore, "VAULT_OVERFLOW");
            } else {
                require(balanceBefore >= balanceDiff, "INSUFFICIENT_VAULT_BALANCE");
            }

            if (strictVaultBalancePolicy) {
                require(minBalance >= 0, "ILLEGAL_BALANCE_REQUIREMENT");
                require(balanceBefore >= minBalance, "UNMET_BALANCE_REQUIREMENT");
            }

            require(newBalance >= 0, "NEGATIVE_BALANCE");
            vaultsBalances[ethAddress][assetId][vaultId] = uint256(newBalance);
            // NOLINTNEXTLINE: reentrancy-events.
            emit LogVaultBalanceChangeApplied(ethAddress, assetId, vaultId, balanceDiff);

            offsetPubInput += PUB_IN_N_WORDS_PER_ONCHAIN_VAULT_UPDATE;
        }
        return offsetPubInput;
    }

    /*
      Verifies that each order was registered by its sender.
        slidingPublicInput - a pointer to the beginning of onchain orders data in publicInput.
        nOnchainOrders - the number of onchain orders.
      Returns the number of publicInput words consumed by this function.
    */
    function verifyOnchainOrders(uint256[] calldata slidingPublicInput, uint256 nOnchainOrders)
        private
        view
        returns (uint256 consumedPubInputItems)
    {
        MessageRegistry orderRegistry = MessageRegistry(orderRegistryAddress);
        uint256 offsetPubInput = 0;

        for (uint256 i = 0; i < nOnchainOrders; i++) {
            // Make sure we remain within slidingPublicInput's bounds.
            require(offsetPubInput + 2 <= slidingPublicInput.length, "Input out of bounds.");
            // First word is the order sender.
            address orderSender = address(slidingPublicInput[offsetPubInput]);
            // Second word is the order blob size (number of blob words) that follow.
            uint256 blobSize = uint256(slidingPublicInput[offsetPubInput + 1]);
            require(offsetPubInput + blobSize + 2 >= offsetPubInput, "Blob size overflow.");

            offsetPubInput += 2;
            require(offsetPubInput + blobSize <= slidingPublicInput.length, "Input out of bounds.");
            // Calculate the hash of the order blob.
            bytes32 orderHash = keccak256(
                abi.encodePacked(slidingPublicInput[offsetPubInput:offsetPubInput + blobSize])
            );

            // Verify this order has been registered.
            require(
                orderRegistry.isMessageRegistered(orderSender, address(this), orderHash),
                "Order not registered."
            );

            offsetPubInput += blobSize;
        }
        return offsetPubInput;
    }
}
