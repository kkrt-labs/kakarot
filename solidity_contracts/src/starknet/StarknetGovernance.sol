/*
  Copyright 2019-2024 StarkWare Industries Ltd.

  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  https://www.starkware.co/open-source-license/

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions
  and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.8.0;

import "./starkware/solidity/components/Governance.sol";

contract StarknetGovernance is Governance {
    string constant STARKNET_GOVERNANCE_INFO_TAG = "STARKNET_1.0_GOVERNANCE_INFO";

    /*
      Returns the GovernanceInfoStruct associated with the governance tag.
    */
    function getGovernanceInfo() internal view override returns (GovernanceInfoStruct storage gub) {
        bytes32 location = keccak256(abi.encodePacked(STARKNET_GOVERNANCE_INFO_TAG));
        assembly {
            gub.slot := location
        }
    }

    function starknetIsGovernor(address user) external view returns (bool) {
        return _isGovernor(user);
    }

    function starknetNominateNewGovernor(address newGovernor) external {
        _nominateNewGovernor(newGovernor);
    }

    function starknetRemoveGovernor(address governorForRemoval) external {
        _removeGovernor(governorForRemoval);
    }

    function starknetAcceptGovernance() external {
        _acceptGovernance();
    }

    function starknetCancelNomination() external {
        _cancelNomination();
    }
}
