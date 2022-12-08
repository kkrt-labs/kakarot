// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../tokens/ERC721/IERC721Receiver.sol";

/*
  ERC721 token receiver interface
  EIP-721 requires any contract receiving ERC721 tokens to implement IERC721Receiver interface.
  By EIP, safeTransferFrom API of ERC721 shall call onERC721Received on the receiving contract.

  Have the receiving contract failed to respond as expected, the safeTransferFrom shall be reverted.

  Params:
  `operator` The address which called `safeTransferFrom` function
  `from` The address which previously owned the token
  `tokenId` The NFT identifier which is being transferred
  `data` Additional data with no specified format

  Returns:
  When invoked by the main contract, following the deposit pattern:
   `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`, which indicates success.
  In all other cases: `bytes4(0)`, which should fail ERC721's safeTransferFrom.
*/
contract ERC721Receiver is IERC721Receiver {
    function onERC721Received(
        address operator, // The address which called `safeTransferFrom` function.
        address, // from - The address which previously owned the token.
        uint256, // tokenId -  The NFT identifier which is being transferred.
        bytes calldata // data - Additional data with no specified format.
    ) external override returns (bytes4) {
        return (operator == address(this) ? this.onERC721Received.selector : bytes4(0));
    }
}
