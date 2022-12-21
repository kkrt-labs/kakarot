// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

abstract contract MKeyGetters {
    // NOLINTNEXTLINE: external-function.
    function getEthKey(uint256 ownerKey) public view virtual returns (address);

    function strictGetEthKey(uint256 ownerKey) internal view virtual returns (address);

    function isMsgSenderKeyOwner(uint256 ownerKey) internal view virtual returns (bool);

    /*
      Allows calling the function only if ownerKey is registered to msg.sender.
    */
    modifier onlyKeyOwner(uint256 ownerKey) {
        // Require the calling user to own the stark key.
        require(msg.sender == strictGetEthKey(ownerKey), "MISMATCHING_STARK_ETH_KEYS");
        _;
    }
}
