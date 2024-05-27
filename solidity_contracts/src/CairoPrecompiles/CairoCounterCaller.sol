// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./ICairo.sol";

contract CairoCounterCaller  {
    /// @dev The Cairo precompile contract's instance.
    ICairo constant CAIRO_PRECOMPILE_CONTRACT = ICairo(CAIRO_PRECOMPILE_ADDRESS);

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

        // Using a low-level call to make it static, and define the function as "view"
        bytes memory call_data = abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", cairoCounterAddress, FUNCTION_SELECTOR_GET, data);
        (bool success, bytes memory returnData) = CAIRO_PRECOMPILE_ADDRESS.staticcall(call_data);
        require(success, "CairoCounterCaller: get counter failed");

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() public {
        // `inc` takes no arguments, so data is empty
        uint256[] memory data;

        // Using a low-level normal call
        bytes memory call_data = abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", cairoCounterAddress, FUNCTION_SELECTOR_INC, data);
        (bool success, bytes memory returnData) = CAIRO_PRECOMPILE_ADDRESS.call(call_data);
        require(success, "CairoCounterCaller: increment counter failed");
    }

    /// @notice Calls the Cairo contract to set its internal counter to an arbitrary value
    /// @dev The counter value is split into two 128-bit values to match the Cairo contract's expected inputs (u256 is composed of two u128s)
    /// @param newCounter The new counter value to set
    function setCairoCounter(uint256 newCounter) public {
        uint128 newCounterLow = uint128(newCounter);
        uint128 newCounterHigh = uint128(newCounter >> 128);

        uint256[] memory data = new uint256[](2);
        data[0] = uint256(newCounterLow);
        data[1] = uint256(newCounterHigh);
        bytes memory call_data = abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", cairoCounterAddress, FUNCTION_SELECTOR_SET_COUNTER, data);
        (bool success, bytes memory returnData) = CAIRO_PRECOMPILE_ADDRESS.call(call_data);
        require(success, "CairoCounterCaller: set counter failed");

        // Using a high-level call
        //TODO: debug why this doesn't pass but the above does.
        // CAIRO_PRECOMPILE_CONTRACT.call_contract(cairoCounterAddress, FUNCTION_SELECTOR_SET_COUNTER, data);

        return;


    // Assembly equivalent of the above code
    //         assembly {
    //     // Prepare the calldata
    //     let call_data := mload(0x40)
    //     mstore8(call_data, 0xb3)
    //     mstore8(add(call_data, 0x01), 0xeb)
    //     mstore8(add(call_data, 0x02), 0x2c)
    //     mstore8(add(call_data, 0x03), 0x1b)
    //     mstore(add(call_data, 0x04), 0x07518340b1c374c88d57719eb0658001b2818da15154841fbee6e7623a2dc593)
    //     mstore(add(call_data, 0x24), FUNCTION_SELECTOR_SET_COUNTER)
    //     mstore(add(call_data, 0x44), 0x60)
    //     mstore(add(call_data, 0x64), 2)
    //     mstore(add(call_data, 0x84), newCounterLow)
    //     mstore(add(call_data, 0x124), newCounterHigh)

    //     mstore(0x40, add(call_data, 0x144))

    //     // Perform the call to the Cairo precompile contract
    //     let success := call(
    //         gas(),
    //         CAIRO_PRECOMPILE_ADDRESS,
    //         0,
    //         call_data,
    //         0x144,
    //         mload(0x40),
    //         32
    //     )

    //     // Check if the call was successful
    //     if iszero(success) {
    //         revert(0, 0)
    //     }
    // }
    }
}
