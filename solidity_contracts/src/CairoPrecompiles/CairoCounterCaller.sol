// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./CairoLib.sol";

contract CairoCounterCaller  {
    /// @dev The cairo contract to call - assuming it's deployed at address 0xabc
    uint256 cairoCounterAddress;

    /// @dev The cairo function selector to call - `inc()`
    uint256 constant FUNCTION_SELECTOR_INC =
    0x03b82f69851fa1625b367ea6c116252a84257da483dcec4d4e4bc270eb5c70a7;

    /// @dev The cairo function selector to call - `set_counter()`
    uint256 constant FUNCTION_SELECTOR_SET_COUNTER = 0x0107cf8c3d109449e1beb4ac1ba726d3673b6f088ae454a9e0f18cb225be4712;

    /// @dev The cairo function selector to call - `get()`
    uint256 constant FUNCTION_SELECTOR_GET = 0x17c00f03de8b5bd58d2016b59d251c13056b989171c5852949903bc043bc27;

    constructor(uint256 cairoContractAddress) {
        cairoCounterAddress = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        // `get_counter` takes no arguments, so data is empty
        uint256[] memory data;
        bytes memory returnData = CairoLib.staticcallContract(cairoCounterAddress, FUNCTION_SELECTOR_GET, data);

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        // `inc` takes no arguments, so data is empty
        uint256[] memory data;
        CairoLib.callContract(cairoCounterAddress, FUNCTION_SELECTOR_INC, data);
    }

    /// @notice Calls the Cairo contract to set its internal counter to an arbitrary value
    /// @dev The counter value is split into two 128-bit values to match the Cairo contract's expected inputs (u256 is composed of two u128s)
    /// @param newCounter The new counter value to set
    function setCairoCounter(uint256 newCounter) external{
        uint128 newCounterLow = uint128(newCounter);
        uint128 newCounterHigh = uint128(newCounter >> 128);

        uint256[] memory data = new uint256[](2);
        data[0] = uint256(newCounterLow);
        data[1] = uint256(newCounterHigh);
        CairoLib.callContract(cairoCounterAddress, FUNCTION_SELECTOR_SET_COUNTER, data);
    }
}
