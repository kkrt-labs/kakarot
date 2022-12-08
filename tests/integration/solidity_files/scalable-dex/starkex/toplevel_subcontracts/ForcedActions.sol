// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interactions/FullWithdrawals.sol";
import "../interactions/StarkExForcedActionState.sol";
import "../../components/Freezable.sol";
import "../../components/KeyGetters.sol";
import "../../components/MainGovernance.sol";
import "../../components/Users.sol";
import "../../interfaces/SubContractor.sol";

contract ForcedActions is
    SubContractor,
    MainGovernance,
    Freezable,
    KeyGetters,
    Users,
    FullWithdrawals,
    StarkExForcedActionState
{
    function initialize(
        bytes calldata /* data */
    ) external override {
        revert("NOT_IMPLEMENTED");
    }

    function initializerSize() external view override returns (uint256) {
        return 0;
    }

    function validatedSelectors()
        external
        pure
        virtual
        override
        returns (bytes4[] memory selectors)
    {
        uint256 len_ = 3;
        uint256 index_ = 0;

        selectors = new bytes4[](len_);
        selectors[index_++] = FullWithdrawals.freezeRequest.selector;
        selectors[index_++] = FullWithdrawals.fullWithdrawalRequest.selector;
        selectors[index_++] = Users.registerEthAddress.selector;
        require(index_ == len_, "INCORRECT_SELECTORS_ARRAY_LENGTH");
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_ForcedActions_2022_3";
    }
}
