// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../components/ApprovalChain.sol";
import "../components/AvailabilityVerifiers.sol";
import "../components/Freezable.sol";
import "../components/MainGovernance.sol";
import "../components/Verifiers.sol";
import "../interfaces/SubContractor.sol";

contract AllVerifiers is
    SubContractor,
    MainGovernance,
    Freezable,
    ApprovalChain,
    AvailabilityVerifiers,
    Verifiers
{
    function initialize(
        bytes calldata /* data */
    ) external override {
        revert("NOT_IMPLEMENTED");
    }

    function initializerSize() external view override returns (uint256) {
        return 0;
    }

    function validatedSelectors() external pure override returns (bytes4[] memory selectors) {
        uint256 len_ = 1;
        uint256 index_ = 0;

        selectors = new bytes4[](len_);
        selectors[index_++] = Freezable.unFreeze.selector;
        require(index_ == len_, "INCORRECT_SELECTORS_ARRAY_LENGTH");
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_AllVerifiers_2022_2";
    }
}
