// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./Operator.sol";
import "./MainStorage.sol";

/**
  Operator implementation for StarkEx (StarkExchange & StarkPerpetual).
*/
abstract contract StarkExOperator is MainStorage, Operator {
    function initialize() internal {
        getOperators()[msg.sender] = true;
        emit LogOperatorAdded(msg.sender);
    }

    function getOperators() internal view override returns (mapping(address => bool) storage) {
        return operators;
    }
}
