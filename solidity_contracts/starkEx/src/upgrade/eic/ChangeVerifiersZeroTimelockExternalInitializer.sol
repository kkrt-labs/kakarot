// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "./ChangeVerifiersExternalInitializer.sol";
import "./ModifyUpgradeDelayExternalInitializer.sol";

/*
  This contract is a simple implementation of an external initializing contract
  that removes all existing verifiers and committees and install the ones provided in parameters.

  It also sets the Proxy upgrade timelock to zero.
*/
contract ChangeVerifiersZeroTimelockExternalInitializer is
    ChangeVerifiersExternalInitializer,
    ModifyUpgradeDelayExternalInitializer
{
    function initialize(bytes calldata data)
        public
        override(ChangeVerifiersExternalInitializer, ModifyUpgradeDelayExternalInitializer)
    {
        ChangeVerifiersExternalInitializer.initialize(data);

        setUpgradeDelay(0);
    }
}
