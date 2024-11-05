// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Ownable2Step, Ownable} from "@openzeppelin-contracts/access/Ownable2Step.sol";
import {CairoLib} from "kakarot-lib/CairoLib.sol";

contract Coinbase is Ownable2Step {
    using CairoLib for uint256;

    uint256 public immutable nativeTokenStarknetAddress;

    /// Constructor sets the owner of the contract
    constructor(uint256 _nativeTokenStarknetAddress) Ownable(msg.sender) {
        nativeTokenStarknetAddress = _nativeTokenStarknetAddress;
    }

    function receiveEther() external payable {}

    /// @notice Withdraws the native token collected by the contract to an address
    /// @dev Uses CairoLib to make a StarknetCall to transfer this contract's balance to a starknet address.
    /// @param toStarknetAddress The Starknet address to withdraw to
    function withdraw(uint256 toStarknetAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        uint128 balanceLow = uint128(balance);
        uint128 balanceHigh = uint128(balance >> 128);
        uint256[] memory data = new uint256[](3);
        data[0] = toStarknetAddress; // recipient
        data[1] = balanceLow;
        data[2] = balanceHigh;
        nativeTokenStarknetAddress.callCairo("transfer", data);
    }
}
