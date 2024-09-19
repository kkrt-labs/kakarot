// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {L2KakarotMessaging} from "./L2KakarotMessaging.sol";
import {AddressAliasHelper} from "./AddressAliasHelper.sol";

contract MessageAppL2 {
    L2KakarotMessaging public immutable l2KakarotMessaging;
    address public immutable l1ContractCounterPart;
    uint256 public receivedMessagesCounter;

    constructor(address l2KakarotMessaging_, address l1ContractCounterPart_) {
        l2KakarotMessaging = L2KakarotMessaging(l2KakarotMessaging_);
        l1ContractCounterPart = l1ContractCounterPart_;
    }

    // @notice Sends a message to L1.
    // @dev Uses the Cairo Precompiles mechanism to invoke the send_message_to_l1 syscall
    function increaseL1AppCounter(address to, uint128 value) external {
        l2KakarotMessaging.sendMessageToL1(to, abi.encode(value));
    }

    function increaseMessagesCounter(uint256 amount) external {
        receivedMessagesCounter += amount;
    }

    function increaseMessageCounterFromL1Contract(uint256 amount) external {
        require(AddressAliasHelper.undoL1ToL2Alias(msg.sender) == l1ContractCounterPart, "ONLY_COUNTERPART_CONTRACT");
        receivedMessagesCounter += amount;
    }
}
