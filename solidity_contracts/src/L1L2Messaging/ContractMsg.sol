// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "starknet/IStarknetMessaging.sol";

// Define some custom error as an example.
// It saves a lot's of space to use those custom error instead of strings.
error InvalidPayload();

/**
   @title Test contract to receive / send messages to starknet.
   @author Glihm https://github.com/glihm/starknet-messaging-dev
*/
contract ContractMsg {

    //
    IStarknetMessaging private _snMessaging;

    /**
       @notice Constructor.

       @param snMessaging The address of Starknet Core contract, responsible
       or messaging.
    */
    constructor(address snMessaging) {
        _snMessaging = IStarknetMessaging(snMessaging);
    }

    /**
       @notice Sends a message to Starknet contract.

       @param contractAddress The contract's address on starknet.
       @param selector The l1_handler function of the contract to call.
       @param payload The serialized data to be sent.

       @dev Consider that Cairo only understands felts252.
       So the serialization on solidity must be adjusted. For instance, a uint256
       must be split in two uint256 with low and high part to be understood by Cairo.
    */
    function sendMessage(
        uint256 contractAddress,
        uint256 selector,
        uint256[] memory payload
    )
        external
        payable
    {
        _snMessaging.sendMessageToL2{value: msg.value}(
            contractAddress,
            selector,
            payload
        );
    }


    /**
       @notice A simple function that sends a message with a pre-determined payload.
    */
    function sendMessageValue(
        uint256 contractAddress,
        uint256 selector,
        uint256 value
    )
        external
        payable
    {
        uint256[] memory payload = new uint256[](1);
        payload[0] = value;

        _snMessaging.sendMessageToL2{value: msg.value}(
            contractAddress,
            selector,
            payload
        );
    }

    /**
       @notice Manually consumes a message that was received from L2.

       @param fromAddress L2 contract (account) that has sent the message.
       @param payload Payload of the message used to verify the hash.

       @dev A message "receive" means that the message hash is registered as consumable.
       One must provide the message content, to let Starknet Core contract verify the hash
       and validate the message content before being consumed.
    */
    function consumeMessage(
        uint256 fromAddress,
        uint256[] calldata payload
    )
        external
    {
        // Will revert if the message is not consumable.
        _snMessaging.consumeMessageFromL2(fromAddress, payload);

        // The previous call returns the message hash (bytes32)
        // that can be used if necessary.

        // You can use the payload to do stuff here as you now know that the message is
        // valid and safe to process.
        // Remember that the payload contains cairo serialized data. So you must
        // deserialize the payload depending on the data it contains.
    }

    /**
       @notice Example of consuming a value received from L2.
    */
    function consumeMessageValue(
        uint256 fromAddress,
        uint256[] calldata payload
    )
        external
    {
        _snMessaging.consumeMessageFromL2(fromAddress, payload);

        // We expect the payload to contain only a felt252 value (which is a uint256 in solidity).
        if (payload.length != 1) {
            revert InvalidPayload();
        }

        uint256 value = payload[0];
        require(value > 0, "Invalid value");
    }

    /**
       @notice Example of consuming a serialized struct from L2.
    */
    function consumeMessageStruct(
        uint256 fromAddress,
        uint256[] calldata payload
    )
        external
    {
        _snMessaging.consumeMessageFromL2(fromAddress, payload);

        // We expect the payload to contain field `a` and `b` from `MyData`.
        if (payload.length != 2) {
            revert InvalidPayload();
        }

        uint256 a = payload[0];
        uint256 b = payload[1];
        require(a > 0 && b > 0, "Invalid value");
    }
}
