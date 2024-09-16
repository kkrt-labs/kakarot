// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "../starknet/IStarknetMessaging.sol";

interface IL1KakarotMessaging {
    function sendMessageToL2(address to, uint248 value, bytes memory data) external payable;
    function consumeMessageFromL2(address fromAddress, bytes calldata payload) external;
}

contract L1KakarotMessaging {
    uint256 public constant HANDLE_L1_MESSAGE_SELECTOR = uint256(keccak256("handle_l1_message")) % 2 ** 250;

    IStarknetMessaging public immutable starknetMessaging;
    uint256 public immutable kakarotAddress;

    constructor(address starknetMessaging_, uint256 kakarotAddress_) {
        starknetMessaging = IStarknetMessaging(starknetMessaging_);
        kakarotAddress = kakarotAddress_;
    }

    /// @notice Sends a message to a contract on L2.
    /// @dev The bytes are split into individual uint256 values to use with the Starknet messaging system.
    /// @dev This function must be called with a value sufficient to pay for the L1 message fee.
    /// @param to The address of the contract on L2 to send the message to.
    /// @param value The value to send to the contract on L2. The value is taken from the L2 contract address.
    /// @param data The data to send to the contract on L2.
    function sendMessageToL2(address to, uint248 value, bytes calldata data) external payable {
        uint256 totalLength = data.length + 4;
        uint256[] memory convertedData = new uint256[](totalLength);
        convertedData[0] = uint256(uint160(msg.sender));
        convertedData[1] = uint256(uint160(to));
        convertedData[2] = uint256(value);
        convertedData[3] = data.length;
        for (uint256 i = 4; i < totalLength; ++i) {
            convertedData[i] = uint256(uint8(data[i - 4]));
        }

        // Send the converted data to L2
        starknetMessaging.sendMessageToL2{value: msg.value}(kakarotAddress, HANDLE_L1_MESSAGE_SELECTOR, convertedData);
    }

    /// @notice Consumes a message sent from L2.
    /// @param fromAddress L2 address sending the message.
    /// @param payload The payload of the message to consume.
    function consumeMessageFromL2(address fromAddress, bytes calldata payload) external {
        // Will revert if the message is not consumable.
        // Consider each byte of calldata as a uint256.
        bytes memory fullPayload = abi.encode(msg.sender, fromAddress, payload);
        uint256 totalLength = fullPayload.length;
        uint256[] memory convertedPayload = new uint256[](totalLength);
        for (uint256 i = 0; i < totalLength; ++i) {
            convertedPayload[i] = uint256(uint8(fullPayload[i]));
        }
        starknetMessaging.consumeMessageFromL2(kakarotAddress, convertedPayload);
    }
}
