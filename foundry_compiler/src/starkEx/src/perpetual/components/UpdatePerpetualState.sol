// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./PerpetualStorage.sol";
import "../interfaces/MForcedTradeActionState.sol";
import "../interfaces/MForcedWithdrawalActionState.sol";
import "../PerpetualConstants.sol";
import "../ProgramOutputOffsets.sol";
import "../../components/OnchainDataFactTreeEncoder.sol";
import "../../components/VerifyFactChain.sol";
import "../../interfaces/MAcceptModifications.sol";
import "../../interfaces/MFreezable.sol";
import "../../interfaces/MOperator.sol";
import "../../libraries/Common.sol";

/**
  TO-DO:DOC.
*/
abstract contract UpdatePerpetualState is
    PerpetualStorage,
    PerpetualConstants,
    MForcedTradeActionState,
    MForcedWithdrawalActionState,
    VerifyFactChain,
    MAcceptModifications,
    MFreezable,
    MOperator,
    ProgramOutputOffsets
{
    event LogUpdateState(uint256 sequenceNumber, uint256 batchId);

    event LogStateTransitionFact(bytes32 stateTransitionFact);

    enum ForcedAction {
        Withdrawal,
        Trade
    }

    struct ProgramOutputMarkers {
        uint256 globalConfigurationHash;
        uint256 nAssets;
        uint256 assetConfigOffset;
        uint256 prevSharedStateSize;
        uint256 prevSharedStateOffset;
        uint256 newSharedStateSize;
        uint256 newSharedStateOffset;
        uint256 newSystemTime;
        uint256 expirationTimestamp;
        uint256 nModifications;
        uint256 modificationsOffset;
        uint256 forcedActionsSize;
        uint256 nForcedActions;
        uint256 forcedActionsOffset;
        uint256 nConditions;
        uint256 conditionsOffset;
    }

    function updateState(uint256[] calldata programOutput, uint256[] calldata applicationData)
        external
        notFrozen
        onlyOperator
    {
        ProgramOutputMarkers memory outputMarkers = parseProgramOutput(programOutput);
        require(
            outputMarkers.expirationTimestamp < 2**PERPETUAL_TIMESTAMP_BITS,
            "Expiration timestamp is out of range."
        );

        require(
            outputMarkers.newSystemTime > (block.timestamp - PERPETUAL_SYSTEM_TIME_LAG_BOUND),
            "SYSTEM_TIME_OUTDATED"
        );

        require(
            outputMarkers.newSystemTime < (block.timestamp + PERPETUAL_SYSTEM_TIME_ADVANCE_BOUND),
            "SYSTEM_TIME_INVALID"
        );

        require(
            outputMarkers.expirationTimestamp > block.timestamp / 3600,
            "BATCH_TIMESTAMP_EXPIRED"
        );

        validateConfigHashes(programOutput, outputMarkers);

        // Caclulate previous shared state hash, and compare with stored one.
        bytes32 prevStateHash = keccak256(
            abi.encodePacked(
                programOutput[outputMarkers.prevSharedStateOffset:outputMarkers
                    .prevSharedStateOffset + outputMarkers.prevSharedStateSize]
            )
        );

        require(prevStateHash == sharedStateHash, "INVALID_PREVIOUS_SHARED_STATE");

        require(
            applicationData[APP_DATA_PREVIOUS_BATCH_ID_OFFSET] == lastBatchId,
            "WRONG_PREVIOUS_BATCH_ID"
        );

        require(
            programOutput.length >=
                outputMarkers.forcedActionsOffset +
                    OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS,
            "programOutput does not contain all required fields."
        );
        bytes32 stateTransitionFact = OnchainDataFactTreeEncoder.encodeFactWithOnchainData(
            programOutput[:programOutput.length -
                OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS],
            OnchainDataFactTreeEncoder.DataAvailabilityFact({
                onchainDataHash: programOutput[programOutput.length - 2],
                onchainDataSize: programOutput[programOutput.length - 1]
            })
        );

        emit LogStateTransitionFact(stateTransitionFact);

        verifyFact(
            verifiersChain,
            stateTransitionFact,
            "NO_STATE_TRANSITION_VERIFIERS",
            "NO_STATE_TRANSITION_PROOF"
        );

        performUpdateState(programOutput, outputMarkers, applicationData);
    }

    function validateConfigHashes(
        uint256[] calldata programOutput,
        ProgramOutputMarkers memory markers
    ) internal view {
        require(globalConfigurationHash != bytes32(0), "GLOBAL_CONFIGURATION_NOT_SET");
        require(
            globalConfigurationHash == bytes32(markers.globalConfigurationHash),
            "GLOBAL_CONFIGURATION_MISMATCH"
        );

        uint256 offset = markers.assetConfigOffset;
        for (uint256 i = 0; i < markers.nAssets; i++) {
            uint256 assetId = programOutput[offset + ASSET_CONFIG_OFFSET_ASSET_ID];
            bytes32 assetConfigHash = bytes32(
                programOutput[offset + ASSET_CONFIG_OFFSET_CONFIG_HASH]
            );
            require(configurationHash[assetId] == assetConfigHash, "ASSET_CONFIGURATION_MISMATCH");
            offset += PROG_OUT_N_WORDS_PER_ASSET_CONFIG;
        }
    }

    function parseProgramOutput(uint256[] calldata programOutput)
        internal
        pure
        returns (ProgramOutputMarkers memory)
    {
        require(
            programOutput.length >= PROG_OUT_N_WORDS_MIN_SIZE,
            "programOutput does not contain all required fields."
        );

        ProgramOutputMarkers memory markers; // NOLINT: uninitialized-local.
        markers.globalConfigurationHash = programOutput[PROG_OUT_GENERAL_CONFIG_HASH];
        markers.nAssets = programOutput[PROG_OUT_N_ASSET_CONFIGS];
        require(markers.nAssets < 2**16, "ILLEGAL_NUMBER_OF_ASSETS");

        uint256 offset = PROG_OUT_ASSET_CONFIG_HASHES;
        markers.assetConfigOffset = offset;
        offset += markers.nAssets * PROG_OUT_N_WORDS_PER_ASSET_CONFIG;
        require(
            programOutput.length >= offset + 1, // Adding +1 for the next mandatory field.
            "programOutput invalid size (nAssetConfig)"
        );

        markers.prevSharedStateSize = programOutput[offset++];
        markers.prevSharedStateOffset = offset;

        offset += markers.prevSharedStateSize;
        require(
            programOutput.length >= offset + 1, // Adding +1 for the next mandatory field.
            "programOutput invalid size (prevState)"
        );

        markers.newSharedStateSize = programOutput[offset++];
        markers.newSharedStateOffset = offset;

        offset += markers.newSharedStateSize;
        require(
            programOutput.length >= offset + 2, // Adding +2 for the next mandatory fields.
            "programOutput invalid size (newState)"
        );

        // System time is the last field in the state.
        markers.newSystemTime = programOutput[offset - 1];

        markers.expirationTimestamp = programOutput[offset++];

        markers.nModifications = programOutput[offset++];
        markers.modificationsOffset = offset;
        offset += markers.nModifications * PROG_OUT_N_WORDS_PER_MODIFICATION;

        markers.forcedActionsSize = programOutput[offset++];
        markers.nForcedActions = programOutput[offset++];
        markers.forcedActionsOffset = offset;
        offset += markers.forcedActionsSize;

        markers.nConditions = programOutput[offset++];
        markers.conditionsOffset = offset;
        offset += markers.nConditions;

        offset += OnchainDataFactTreeEncoder.ONCHAIN_DATA_FACT_ADDITIONAL_WORDS;

        require(
            programOutput.length == offset,
            "programOutput invalid size (mods/forced/conditions)"
        );
        return markers;
    }

    function performUpdateState(
        uint256[] calldata programOutput,
        ProgramOutputMarkers memory markers,
        uint256[] calldata applicationData
    ) internal {
        sharedStateHash = keccak256(
            abi.encodePacked(
                programOutput[markers.newSharedStateOffset:markers.newSharedStateOffset +
                    markers.newSharedStateSize]
            )
        );

        sequenceNumber += 1;
        uint256 batchId = applicationData[APP_DATA_BATCH_ID_OFFSET];
        lastBatchId = batchId;

        sendModifications(programOutput, markers, applicationData);

        verifyConditionalTransfers(programOutput, markers, applicationData);

        clearForcedActionsFlags(programOutput, markers);

        emit LogUpdateState(sequenceNumber, batchId);
    }

    /*
      Goes through the program output forced actions section,
      extract each forced action, and if valid and its flag exists, clears it.
      If invalid, or not flag not exist - revert.
    */
    function clearForcedActionsFlags(
        uint256[] calldata programOutput,
        ProgramOutputMarkers memory markers
    ) private {
        uint256 offset = markers.forcedActionsOffset;
        for (uint256 i = 0; i < markers.nForcedActions; i++) {
            ForcedAction forcedActionType = ForcedAction(programOutput[offset++]);
            if (forcedActionType == ForcedAction.Withdrawal) {
                offset = clearForcedWithdrawal(programOutput, offset);
            } else if (forcedActionType == ForcedAction.Trade) {
                offset = clearForcedTrade(programOutput, offset);
            } else {
                revert("UNKNOWN_FORCED_ACTION_TYPE");
            }
        }
        // Ensure all sizes are matching (this is not checked in parsing).
        require(markers.forcedActionsOffset + markers.forcedActionsSize == offset, "SIZE_MISMATCH");
    }

    function clearForcedWithdrawal(uint256[] calldata programOutput, uint256 offset)
        private
        returns (uint256)
    {
        uint256 starkKey = programOutput[offset++];
        uint256 vaultId = programOutput[offset++];
        uint256 quantizedAmount = programOutput[offset++];
        clearForcedWithdrawalRequest(starkKey, vaultId, quantizedAmount);
        return offset;
    }

    function clearForcedTrade(uint256[] calldata programOutput, uint256 offset)
        private
        returns (uint256)
    {
        uint256 starkKeyA = programOutput[offset++];
        uint256 starkKeyB = programOutput[offset++];
        uint256 vaultIdA = programOutput[offset++];
        uint256 vaultIdB = programOutput[offset++];
        // CollateralAssetId Not taken from progOutput. We use systemAssetType.
        uint256 syntheticAssetId = programOutput[offset++];
        uint256 amountCollateral = programOutput[offset++];
        uint256 amountSynthetic = programOutput[offset++];
        bool aIsBuyingSynthetic = (programOutput[offset++] != 0);
        uint256 nonce = programOutput[offset++];
        clearForcedTradeRequest(
            starkKeyA,
            starkKeyB,
            vaultIdA,
            vaultIdB,
            systemAssetType,
            syntheticAssetId,
            amountCollateral,
            amountSynthetic,
            aIsBuyingSynthetic,
            nonce
        );
        return offset;
    }

    function verifyConditionalTransfers(
        uint256[] calldata programOutput,
        ProgramOutputMarkers memory markers,
        uint256[] calldata applicationData
    ) private view {
        require(applicationData.length >= APP_DATA_N_CONDITIONAL_TRANSFER, "APP_DATA_TOO_SHORT");

        require(
            applicationData[APP_DATA_N_CONDITIONAL_TRANSFER] == markers.nConditions,
            "N_CONDITIONS_MISMATCH"
        );

        require(
            applicationData.length >=
                APP_DATA_CONDITIONAL_TRANSFER_DATA_OFFSET +
                    markers.nConditions *
                    APP_DATA_N_WORDS_PER_CONDITIONAL_TRANSFER,
            "BAD_APP_DATA_SIZE"
        );

        uint256 conditionsOffset = markers.conditionsOffset;
        uint256 preImageOffset = APP_DATA_CONDITIONAL_TRANSFER_DATA_OFFSET;

        // Conditional Transfers appear after all other modifications.
        for (uint256 i = 0; i < markers.nConditions; i++) {
            address transferRegistry = address(applicationData[preImageOffset]);
            bytes32 transferFact = bytes32(applicationData[preImageOffset + 1]);
            uint256 condition = programOutput[conditionsOffset];

            // The condition is the 250 LS bits of keccak256 of the fact registry & fact.
            require(
                condition ==
                    uint256(keccak256(abi.encodePacked(transferRegistry, transferFact))) & MASK_250,
                "Condition mismatch."
            );
            // NOLINTNEXTLINE: low-level-calls-loop reentrancy-events.
            (bool success, bytes memory returndata) = transferRegistry.staticcall(
                abi.encodeWithSignature("isValid(bytes32)", transferFact)
            );
            require(success && returndata.length == 32, "BAD_FACT_REGISTRY_CONTRACT");
            require(
                abi.decode(returndata, (bool)),
                "Condition for the conditional transfer was not met."
            );
            conditionsOffset += 1;
            preImageOffset += APP_DATA_N_WORDS_PER_CONDITIONAL_TRANSFER;
        }
    }

    function sendModifications(
        uint256[] calldata programOutput,
        ProgramOutputMarkers memory markers,
        uint256[] calldata /*applicationData*/
    ) private {
        uint256 assetId = systemAssetType;
        require(assetId < K_MODULUS, "Asset id >= PRIME");

        uint256 offset = markers.modificationsOffset;
        for (uint256 i = 0; i < markers.nModifications; i++) {
            uint256 starkKey = programOutput[offset + MODIFICATIONS_OFFSET_STARKKEY];
            uint256 vaultId = programOutput[offset + MODIFICATIONS_OFFSET_POS_ID];
            uint256 biasedDiff = programOutput[offset + MODIFICATIONS_OFFSET_BIASED_DIFF];
            // Biased representation.
            // biased_delta is in range [0, 2**65), where 2**64 means 0 change.
            // The effective difference is biased_delta - 2**64.
            require(biasedDiff < (1 << 65), "Illegal Balance Diff");
            int256 balanceDiff = int256(biasedDiff - (1 << 64));

            require(starkKey < K_MODULUS, "Stark key >= PRIME");

            if (balanceDiff > 0) {
                // This is a deposit.
                acceptDeposit(starkKey, vaultId, assetId, uint256(balanceDiff));
            } else if (balanceDiff < 0) {
                // This is a withdrawal.
                acceptWithdrawal(starkKey, assetId, uint256(-balanceDiff));
            }
            offset += PROG_OUT_N_WORDS_PER_MODIFICATION;
        }
    }
}
