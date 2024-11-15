// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {CairoLib} from "kakarot-lib/CairoLib.sol";
import {NoDelegateCall} from "../NoDelegateCall/NoDelegateCall.sol";

contract L2KakarotMessaging is NoDelegateCall {
    /// @notice Sends a message to a contract on L1.
    /// @dev This function is noDelegateCall to prevent attack vectors where a
    /// contract can send messages to L1 with arbitrary target addresses and payloads;
    /// these messages appear as originated by victim's EVM address.
    /// @param to The address of the contract on L1 to send the message to.
    /// @param data The data to send to the contract on L1.
    function sendMessageToL1(address to, bytes calldata data) external noDelegateCall {
        bytes memory payload = abi.encode(to, msg.sender, data);
        CairoLib.sendMessageToL1(payload);
    }
}
