// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {L2KakarotMessaging} from "./L2KakarotMessaging.sol";

contract MessageAppL2 {
    L2KakarotMessaging immutable l2KakarotMessaging;
    uint256 public receivedMessagesCounter;

    constructor(address _l2KakarotMessaging) {
        l2KakarotMessaging = L2KakarotMessaging(_l2KakarotMessaging);
    }

    // @notice Sends a message to L1.
    // @dev Uses the Cairo Precompiles mechanism to invoke the send_message_to_l1 syscall
    function increaseL1AppCounter(address to, uint128 value) external {
        l2KakarotMessaging.sendMessageToL1(to, abi.encode(value));
    }

    function increaseMessagesCounter(uint256 amount) external {
        receivedMessagesCounter += amount;
    }
}
