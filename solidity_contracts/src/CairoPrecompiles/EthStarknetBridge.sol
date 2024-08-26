// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

contract EthStarknetBridge {
    // State variable to store the owner of the contract
    address public owner;

    // Constructor sets the owner of the contract
    constructor() {
        owner = msg.sender;
    }

    // Modifier to restrict access to owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    /// @dev The cairo contract to call
    uint256 constant starknetEth = 0x49D36570D4E46F48E99674BD3FCC84644DDD6B96F7C741B1562B82F9E004DC7;
    uint256 constant TRANSFER_SELECTOR = uint256(keccak256("transfer")) % 2 ** 250;

    /// @notice Withdraws ETH from the contract to a Starknet address
    function withdraw(uint256 toStarknetAddress) external onlyOwner {
        uint256 balance = address(this).balance;
        transfer(toStarknetAddress, balance);
    }

    /// @notice Calls the Eth Cairo contract
    /// @param toStarknetAddress The Starknet address to send ETH to
    /// @param amount The amount of ETH to send
    function transfer(uint256 toStarknetAddress, uint256 amount) public {
        // Split amount in [low, high]
        uint128 amountLow = uint128(amount);
        uint128 amountHigh = uint128(amount >> 128);

        uint256[] memory transferCallData = new uint256[](3);
        transferCallData[0] = toStarknetAddress;
        transferCallData[1] = uint256(amountLow);
        transferCallData[2] = uint256(amountHigh);

        // TODO: fine tune the 100_000 gas limit
        require(gasleft() > 100_000, "Not enough gas to call Eth Cairo contract");
        starknetEth.delegatecallCairo(TRANSFER_SELECTOR, transferCallData);
    }
}
