// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {L2KakarotMessaging} from "../L1L2Messaging/L2KakarotMessaging.sol";

contract L2MessagingHack {
    L2KakarotMessaging public immutable target;

    constructor(address _target) {
        target = L2KakarotMessaging(_target);
    }

    function trySendMessageToL1(address to, bytes calldata data) external returns (bool success) {
        // Try to send message through delegatecall
        (success,) =
            address(target).delegatecall(abi.encodeWithSelector(L2KakarotMessaging.sendMessageToL1.selector, to, data));
    }
}
