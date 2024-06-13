// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./L1KakarotMessaging.sol";
import "./MessageAppL2.sol";

// Define some custom error as an example.
// It saves a lot's of space to use those custom error instead of strings.
error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
   @author Glihm https://github.com/glihm/starknet-messaging-dev
*/
contract MessageAppL1 {

    //
    IL1KakarotMessaging private _l1KakarotMessaging;
    uint256 private _kakarotAddress;
    uint256 public receivedMessagesCounter;

    /**
       @notice Constructor.

       @param l1KakarotMessaging The address of the L1KakarotMessaging contract.
       @param kakarotAddress The Starknet address, on L2, of the Kakarot contract.
    */
    constructor(address l1KakarotMessaging, uint256 kakarotAddress) {
        _l1KakarotMessaging = IL1KakarotMessaging(l1KakarotMessaging);
        _kakarotAddress = kakarotAddress;
    }

    /// @notice Increases the counter inside the MessageAppL2 contract deployed on Kakarot.
    /// @dev Must be called with a value sufficient to pay for the L1 message fee.
    /// @param l2AppAddress The address of the L2 contract to trigger.
    function increaseL2AppCounter(
        address l2AppAddress
    )
        external
        payable
    {
        _l1KakarotMessaging.sendMessageToL2{value: msg.value}(
            l2AppAddress,
            0,
            abi.encodeCall(
                MessageAppL2.increaseMessagesCounter,
                (
                    1
                )
            )
        );
    }


    /**
       @notice Manually consumes a message that was received from L2.
       @param payload Payload of the message used to verify the hash.
       @dev A message "received" means that the message hash is registered as consumable.
       One must provide the message content, to let Starknet Core contract verify the hash
       and validate the message content before being consumed.
       The L1KakarotMessaging contract must be called with a delegatecall to ensure that
       the Starknet Core contract considers this contract as the consumer.
    */
    function consumeCounterIncrease(
        uint256[] calldata payload
    )
        external
    {
        // Will revert if the message is not consumable.
        (bool success, bytes memory msghash) = address(_l1KakarotMessaging).delegatecall(abi.encodeWithSignature("consumeMessageFromL2(uint256[])", payload));

        // The previous call returns the message hash (bytes32)
        // that can be used if necessary.

        uint256 value = payload[0];
        receivedMessagesCounter += value;
        // You can use the payload to do stuff here as you now know that the message is
        // valid and safe to process.
        // Remember that the payload contains cairo serialized data. So you must
        // deserialize the payload depending on the data it contains.
    }
}
