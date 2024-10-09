// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {DualVmToken} from "../CairoPrecompiles/DualVmToken.sol";

contract Coinbase {
    /// @dev State variable to store the owner of the contract
    address immutable owner;

    /// @dev The EVM address of the DualVmToken for Kakarot ETH.
    /// @dev DualVmToken.balanceOf(this) is the same as address(this).balance
    DualVmToken immutable kakarotEth;

    /// Constructor sets the owner of the contract
    constructor(address _kakarotEth) {
        owner = msg.sender;
        kakarotEth = DualVmToken(_kakarotEth);
    }

    /// Modifier to restrict access to owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /// @notice Withdraws ETH from the contract to a Starknet address
    function withdraw(uint256 toStarknetAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        kakarotEth.transfer(toStarknetAddress, balance);
    }
}
