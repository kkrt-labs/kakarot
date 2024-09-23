pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {L1KakarotMessaging} from "../src/L1L2Messaging/L1KakarotMessaging.sol";
import {StarknetMessagingLocal} from "../src/starknet/StarknetMessagingLocal.sol";
import {AddressAliasHelper} from "../src/L1L2Messaging/AddressAliasHelper.sol";

contract L1KakarotMessagingTest is Test {
    L1KakarotMessaging l1KakarotMessaging;
    StarknetMessagingLocal starknetMessagingLocal;
    uint256 mockedKakarot = 0xFF1;

    function setUp() public {
        starknetMessagingLocal = new StarknetMessagingLocal();
        l1KakarotMessaging = new L1KakarotMessaging(address(starknetMessagingLocal), mockedKakarot);
    }

    function getL1ToL2MsgHash(uint256 toAddress, uint256 selector, uint256[] memory payload, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                uint256(uint160(address(l1KakarotMessaging))), toAddress, nonce, selector, payload.length, payload
            )
        );
    }

    function test_sendMessageToL2(address to, uint248 value, bytes memory data) public {
        vm.assume(value <= starknetMessagingLocal.getMaxL1MsgFee());
        deal(address(this), 100 ether);
        l1KakarotMessaging.sendMessageToL2{value: 0.1 ether}(to, value, data);

        uint256 totalLength = data.length + 4;
        uint256[] memory convertedData = new uint256[](totalLength);
        convertedData[0] = uint256(uint160(AddressAliasHelper.applyL1ToL2Alias(address(this))));
        convertedData[1] = uint256(uint160(to));
        convertedData[2] = value;
        convertedData[3] = data.length;
        for (uint256 i = 4; i < totalLength; ++i) {
            convertedData[i] = uint256(uint8(data[i - 4]));
        }

        bytes32 msgHash =
            getL1ToL2MsgHash(mockedKakarot, l1KakarotMessaging.HANDLE_L1_MESSAGE_SELECTOR(), convertedData, 0);

        assertEq(starknetMessagingLocal.l1ToL2Messages(msgHash), 0.1 ether + 1);
    }

    function test_consumeMessageFromL2(address fromAddress, bytes memory payload) public {
        deal(address(this), 100 ether);
        bytes memory fullPayload = abi.encode(address(this), fromAddress, payload);
        uint256 totalLength = fullPayload.length;
        uint256[] memory convertedPayload = new uint256[](totalLength);
        for (uint256 i = 0; i < totalLength; ++i) {
            convertedPayload[i] = uint256(uint8(fullPayload[i]));
        }
        // Ensures the consumeMessageFromL2 function is called with the correct parameters.
        vm.mockCall(
            address(starknetMessagingLocal),
            abi.encodeWithSelector(
                starknetMessagingLocal.consumeMessageFromL2.selector, mockedKakarot, convertedPayload
            ),
            abi.encode(true)
        );
        l1KakarotMessaging.consumeMessageFromL2(fromAddress, payload);
    }
}
