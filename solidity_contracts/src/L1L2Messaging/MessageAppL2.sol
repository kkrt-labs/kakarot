// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

contract MessageAppL2 {
    uint256 public receivedMessagesCounter;

    // @notice Sends a message to L1.
    // @dev Uses the Cairo Precompiles mechanism to invoke a the send_message_to_l1 syscall
    function increaseL1AppCounter(address to, uint128 value) external {
        bytes memory data = abi.encode(value);
        CairoLib.sendMessageToL1(to, data);
    }

    function increaseMessagesCounter(uint256 amount) external {
        receivedMessagesCounter += amount;
    }
}
