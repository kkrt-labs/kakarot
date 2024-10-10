// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {DualVmToken} from "../CairoPrecompiles/DualVmToken.sol";

contract Coinbase {
    /// @dev The EVM address of the DualVmToken for Kakarot ETH.
    DualVmToken public immutable kakarotEth;

    /// @dev State variable to store the owner of the contract
    address public owner;

    /// Constructor sets the owner of the contract
    constructor(address _kakarotEth) {
        owner = msg.sender;
        kakarotEth = DualVmToken(_kakarotEth);
    }

    /// Modifier to restrict access to owner only
    /// @dev Assert that msd.sender is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /// @notice Withdraws ETH from the contract to a Starknet address
    /// @dev DualVmToken.balanceOf(this) is the same as address(this).balance
    /// @param toStarknetAddress The Starknet address to withdraw to
    function withdraw(uint256 toStarknetAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        kakarotEth.transfer(toStarknetAddress, balance);
    }

    /// @notice Transfers ownership of the contract to a new address
    /// @param newOwner The address to transfer ownership to
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
}
