// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../CairoPrecompiles/CairoLib.sol";

contract MessageSenderL2  {
    // @notice Sends a message to L1.
    // @dev Uses the Cairo Precompiles mechanism to invoke a the send_message_to_l1 syscall
    function sendMessageToL1(address to, uint128 value) external {
        uint248[] memory data = new uint248[](1);
        data[0] = uint248(value);
        CairoLib.sendMessageToL1(to, data);
    }
}
