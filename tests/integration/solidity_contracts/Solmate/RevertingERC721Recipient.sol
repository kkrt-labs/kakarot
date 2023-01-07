// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721TokenReceiver} from "./ERC721.sol";

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)));
    }
}
