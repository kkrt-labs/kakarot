// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../interfaces/SubContractor.sol";
import "../../upgrade/ProxyGovernance.sol";
import "../../upgrade/ProxyStorage.sol";
import "../../upgrade/StorageSlots.sol";

contract ProxyUtils is SubContractor, StorageSlots, ProxyGovernance, ProxyStorage {
    event ImplementationActivationRescheduled(
        address indexed implementation,
        uint256 updatedActivationTime
    );

    function initialize(
        bytes calldata /* data */
    ) external override {
        revert("NOT_IMPLEMENTED");
    }

    function initializerSize() external view override returns (uint256) {
        return 0;
    }

    function storedActivationDelay() internal view returns (uint256 delay) {
        bytes32 slot = UPGRADE_DELAY_SLOT;
        assembly {
            delay := sload(slot)
        }
        return delay;
    }

    function updateImplementationActivationTime(
        address implementation,
        bytes calldata data,
        bool finalize
    ) external onlyGovernance {
        uint256 updatedActivationTime = block.timestamp + storedActivationDelay();

        // We assume the Proxy is of the old format.
        bytes32 oldFormatInitHash = keccak256(abi.encode(data, finalize));
        require(
            initializationHash_DEPRECATED[implementation] == oldFormatInitHash,
            "IMPLEMENTATION_NOT_PENDING"
        );

        // Converting address to bytes32 to match the mapping key type.
        bytes32 implementationKey;
        assembly {
            implementationKey := implementation
        }
        uint256 pendingActivationTime = enabledTime[implementationKey];

        require(pendingActivationTime > 0, "IMPLEMENTATION_NOT_PENDING");

        // Current value is checked to be within a reasonable delay. If it's over 6 months from now,
        // it's assumed that the activation time is configured under a different set of rules.
        require(
            pendingActivationTime < block.timestamp + 180 days,
            "INVALID_PENDING_ACTIVATION_TIME"
        );

        if (updatedActivationTime < pendingActivationTime) {
            enabledTime[implementationKey] = updatedActivationTime;
            emit ImplementationActivationRescheduled(implementation, updatedActivationTime);
        }
    }

    function validatedSelectors() external pure override returns (bytes4[] memory selectors) {
        // This sub-contract has no selectors to validate.
        selectors = new bytes4[](0);
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_ProxyUtils_2022_2";
    }
}
