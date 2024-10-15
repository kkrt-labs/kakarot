// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

contract WhitelistedCallCairoPrecompileTest {
    /// @dev The cairo contract to call
    uint256 immutable cairoCounter;

    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        bytes memory returnData = cairoCounter.staticcallCairo("get");

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev The delegatecall preserves the caller's context, so the caller's address will
    /// be the caller of this function.
    function delegateCallIncrementCairoCounter() external {
        cairoCounter.delegatecallCairo("inc");
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        cairoCounter.callCairo("inc");
    }

    /// @notice Calls the Cairo contract to set its internal counter to an arbitrary value
    /// @dev Called with a regular call, the caller's address will be this contract's address
    /// @dev The counter value is split into two 128-bit values to match the Cairo contract's expected inputs (u256 is composed of two u128s)
    /// @param newCounter The new counter value to set
    function setCairoCounter(uint256 newCounter) external {
        // The u256 input must be split into two u128 values to match the expected cairo input
        uint128 newCounterLow = uint128(newCounter);
        uint128 newCounterHigh = uint128(newCounter >> 128);

        uint256[] memory data = new uint256[](2);
        data[0] = uint256(newCounterLow);
        data[1] = uint256(newCounterHigh);
        cairoCounter.callCairo("set_counter", data);
    }

    /// @notice Calls the Cairo contract to get the (starknet) address of the last caller
    /// @return lastCaller The starknet address of the last caller
    function getLastCaller() external view returns (uint256 lastCaller) {
        bytes memory returnData = cairoCounter.staticcallCairo("get_last_caller");

        return abi.decode(returnData, (uint256));
    }
}
