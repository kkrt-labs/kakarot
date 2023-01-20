// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721TokenReceiver} from "./ERC721.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from_;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from_ = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
