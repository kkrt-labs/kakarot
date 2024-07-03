// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./CairoLib.sol";

using CairoLib for uint256;

contract CairoCounterCaller {
    /// @dev The cairo contract to call
    uint256 cairoCounter;

    /// @dev The cairo function selector to call - `inc`
    uint256 constant FUNCTION_SELECTOR_INC = uint256(keccak256("inc")) % 2 ** 250;

    /// @dev The cairo function selector to call - `set_counter`
    uint256 constant FUNCTION_SELECTOR_SET_COUNTER = uint256(keccak256("set_counter")) % 2 ** 250;

    /// @dev The cairo function selector to call - `get`
    uint256 constant FUNCTION_SELECTOR_GET = uint256(keccak256("get")) % 2 ** 250;

    uint256 constant FUNCTION_SELECTOR_GET_LAST_CALLER = uint256(keccak256("get_last_caller")) % 2 ** 250;

    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        bytes memory returnData = cairoCounter.staticcallContract(FUNCTION_SELECTOR_GET);

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        cairoCounter.callContract("inc");
    }

    /// @notice Calls the Cairo contract to set its internal counter to an arbitrary value
    /// @dev The counter value is split into two 128-bit values to match the Cairo contract's expected inputs (u256 is composed of two u128s)
    /// @param newCounter The new counter value to set
    function setCairoCounter(uint256 newCounter) external {
        // The u256 input must be split into two u128 values to match the expected cairo input
        uint128 newCounterLow = uint128(newCounter);
        uint128 newCounterHigh = uint128(newCounter >> 128);

        uint256[] memory data = new uint256[](2);
        data[0] = uint256(newCounterLow);
        data[1] = uint256(newCounterHigh);
        cairoCounter.callContract(FUNCTION_SELECTOR_SET_COUNTER, data);
    }

    /// @notice Calls the Cairo contract to get the (starknet) address of the last caller
    /// @return lastCaller The starknet address of the last caller
    function getLastCaller() external view returns (uint256 lastCaller) {
        bytes memory returnData = cairoCounter.staticcallContract(FUNCTION_SELECTOR_GET_LAST_CALLER);

        return abi.decode(returnData, (uint256));
    }
}
