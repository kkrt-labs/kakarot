// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {DualVmToken} from "../CairoPrecompiles/DualVmToken.sol";
import {Ownable2Step, Ownable} from "@openzeppelin-contracts/access/Ownable2Step.sol";

contract Coinbase is Ownable2Step {
    /// @dev The EVM address of the DualVmToken for Kakarot ETH.
    DualVmToken public immutable kakarotEth;

    /// Constructor sets the owner of the contract
    constructor(address _kakarotEth) Ownable(msg.sender) {
        kakarotEth = DualVmToken(_kakarotEth);
    }

    /// @notice Withdraws ETH from the contract to a Starknet address
    /// @dev DualVmToken.balanceOf(this) is the same as address(this).balance
    /// @param toStarknetAddress The Starknet address to withdraw to
    function withdraw(uint256 toStarknetAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        kakarotEth.transfer(toStarknetAddress, balance);
    }
}
