// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

contract L2KakarotMessaging {
    /// @notice Sends a message to a contract on L1.
    /// @param to The address of the contract on L1 to send the message to.
    /// @param data The data to send to the contract on L1.
    function sendMessageToL1(address to, bytes calldata data) external payable {
        bytes memory payload = abi.encode(msg.sender, data);
        CairoLib.sendMessageToL1(to, payload);
    }
}
