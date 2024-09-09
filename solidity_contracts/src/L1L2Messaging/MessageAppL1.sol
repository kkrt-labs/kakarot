// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./L1KakarotMessaging.sol";
import "./MessageAppL2.sol";
import "../starknet/IStarknetMessaging.sol";

// Define some custom error as an example.
// It saves a lot's of space to use those custom error instead of strings.
error InvalidPayload();

/// @title Test contract to receive / send messages to starknet.
/// @author Glihm https://github.com/glihm/starknet-messaging-dev
contract MessageAppL1 {
    IStarknetMessaging private _starknetMessaging;
    IL1KakarotMessaging private _l1KakarotMessaging;
    uint256 private _kakarotAddress;
    uint256 public receivedMessagesCounter;

    event CallerPrecompile(address caller, bytes payload);

    /// @notice Constructor.
    /// @param starknetMessaging The address of the StarknetMessaging contract.
    /// @param l1KakarotMessaging The address of the L1KakarotMessaging contract.
    /// @param kakarotAddress The Starknet address, on L2, of the Kakarot contract.
    constructor(address starknetMessaging, address l1KakarotMessaging, uint256 kakarotAddress) {
        _starknetMessaging = IStarknetMessaging(starknetMessaging);
        _l1KakarotMessaging = IL1KakarotMessaging(l1KakarotMessaging);
        _kakarotAddress = kakarotAddress;
    }

    /// @notice Increases the counter inside the MessageAppL2 contract deployed on Kakarot.
    /// @dev Must be called with a value sufficient to pay for the L1 message fee.
    /// @param l2AppAddress The address of the L2 contract to trigger.
    function increaseL2AppCounter(address l2AppAddress) external payable {
        _l1KakarotMessaging.sendMessageToL2{value: msg.value}(
            l2AppAddress, 0, abi.encodeCall(MessageAppL2.increaseMessagesCounter, 1)
        );
    }

    /// @notice Manually consumes a message that was received from L2.
    /// @param payload Payload of the message used to verify the hash.
    /// @dev A message "received" means that the message hash is registered as consumable.
    /// One must provide the message content, to let Starknet Core contract verify the hash
    /// and validate the message content before being consumed.
    /// The L1KakarotMessaging contract must be called with a delegatecall to ensure that
    /// the Starknet Core contract considers this contract as the consumer.
    function consumeCounterIncrease(bytes calldata payload) external {
        // Will revert if the message is not consumable.
        // Delegatecall to _l1KakarotMessaging
        (bool success,) =
            address(_l1KakarotMessaging).delegatecall(abi.encodeWithSignature("consumeMessageFromL2(bytes)", payload));
        require(success, "message consumption failed");

        // Decode the uint256 value from the payload
        (address caller, bytes memory data) = abi.decode(payload, (address, bytes));
        uint256 value = abi.decode(data, (uint256));
        receivedMessagesCounter += value;
        emit CallerPrecompile(caller, data);
    }
}
