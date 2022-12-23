// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../../interfaces/ExternalInitializer.sol";
import "../../perpetual/components/PerpetualStorage.sol";

/*
  This contract is an external initializing contract that modifies the upgradability proxy
  upgrade activation delay.
*/
contract ModifyConfigurationDelayExternalInitializer is ExternalInitializer, PerpetualStorage {
    uint256 constant MAX_CONFIG_DELAY = 28 days;

    function initialize(bytes calldata data) external override {
        require(data.length == 32, "INCORRECT_INIT_DATA_SIZE_32");
        uint256 delayInSeconds;
        (delayInSeconds) = abi.decode(data, (uint256));

        require(delayInSeconds <= MAX_CONFIG_DELAY, "DELAY_TIME_TOO_LONG");
        configurationDelay = delayInSeconds;

        emit LogExternalInitialize(data);
    }
}
