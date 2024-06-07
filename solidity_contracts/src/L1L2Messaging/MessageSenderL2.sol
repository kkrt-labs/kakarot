// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../CairoPrecompiles/CairoLib.sol";

using CairoLib for uint256;

contract MessageSenderL2  {
    /// @dev The starknet address of the Kakarot L2 Messaging contract
    uint256 messagingContract;

    /// @dev The cairo function selector to call
    uint256 constant SEND_MESSAGE_VALUE = uint256(keccak256("send_message_value")) % 2**250;

    constructor(uint256 messagingContractAddress) {
        messagingContract = messagingContractAddress;
    }

    // @notice Sends a message to L1.
    // @dev Uses the Cairo Precompiles mechanism to invoke a Cairo contract that uses the Starknet
    // messaging system.
    function sendMessageToL1() external {
        uint256[] memory data = new uint256[](2);
        data[0] = 0x1234;
        data[1] = 0;
        messagingContract.callContract(SEND_MESSAGE_VALUE, data);
    }
}
