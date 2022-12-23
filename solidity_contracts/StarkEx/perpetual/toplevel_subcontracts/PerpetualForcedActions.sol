// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interactions/ForcedTrades.sol";
import "../interactions/ForcedTradeActionState.sol";
import "../interactions/ForcedWithdrawals.sol";
import "../interactions/ForcedWithdrawalActionState.sol";
import "../../components/Freezable.sol";
import "../../components/KeyGetters.sol";
import "../../components/MainGovernance.sol";
import "../../components/Users.sol";
import "../../interfaces/SubContractor.sol";

contract PerpetualForcedActions is
    SubContractor,
    MainGovernance,
    Freezable,
    KeyGetters,
    Users,
    ForcedTrades,
    ForcedTradeActionState,
    ForcedWithdrawals,
    ForcedWithdrawalActionState
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
        uint256 len_ = 5;
        uint256 index_ = 0;

        selectors = new bytes4[](len_);
        selectors[index_++] = ForcedTrades.forcedTradeRequest.selector;
        selectors[index_++] = ForcedTrades.freezeRequest.selector;
        selectors[index_++] = ForcedWithdrawals.forcedWithdrawalRequest.selector;
        selectors[index_++] = ForcedWithdrawals.freezeRequest.selector;
        selectors[index_++] = Users.registerEthAddress.selector;
        require(index_ == len_, "INCORRECT_SELECTORS_ARRAY_LENGTH");
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_PerpetualForcedActions_2022_2";
    }
}
