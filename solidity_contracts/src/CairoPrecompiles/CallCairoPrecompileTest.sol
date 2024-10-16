// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract CallCairoPrecompileTest {
    using CallCairoLib for uint256;

    /// @dev The cairo contract to call
    uint256 immutable cairoCounter;

    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    function getCairoCounter() public view returns (uint256 counterValue) {
        uint256[] memory data = new uint256[](0);
        bytes memory returnData = cairoCounter.staticcallCairo("get", data);

        // The return data is a 256-bit integer, so we can directly cast it to uint256
        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        uint256[] memory data = new uint256[](0);
        cairoCounter.callCairo("inc", data);
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
        uint256[] memory data = new uint256[](0);
        bytes memory returnData = cairoCounter.staticcallCairo("get_last_caller", data);

        return abi.decode(returnData, (uint256));
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev The delegatecall preserves the caller's context, so the caller's address will
    /// be the caller of this function.
    /// @dev Should always fail, as MulticallCairo does not support delegatecalls.
    function incrementCairoCounterDelegatecall() external {
        uint256[] memory data = new uint256[](0);
        cairoCounter.delegatecallCairo("inc", data);
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev Called with a regular call, the caller's address will be this contract's address
    /// @dev Should always fail, as MulticallCairo does not support callcode.
    function incrementCairoCounterCallcode() external {
        uint256[] memory data = new uint256[](0);
        cairoCounter.callcodeCairo("inc", data);
    }
}

library CallCairoLib {
    address constant CALL_CAIRO_PRECOMPILE = 0x0000000000000000000000000000000000075004;

    function callCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CALL_CAIRO_PRECOMPILE.call(callData);
        require(success, string(abi.encodePacked("CairoLib: cairo call failed with: ", result)));

        return result;
    }

    function staticcallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        view
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CALL_CAIRO_PRECOMPILE.staticcall(callData);
        require(success, string(abi.encodePacked("CairoLib: cairo call failed with: ", result)));

        return result;
    }

    function delegatecallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CALL_CAIRO_PRECOMPILE.delegatecall(callData);
        require(success, string(abi.encodePacked("CairoLib: cairo call failed with: ", result)));

        return result;
    }

    function callcodeCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData = abi.encode(contractAddress, functionSelector, data);

        bool success;
        bytes memory result;

        // Use inline assembly for callcode
        assembly {
            // Allocate memory for the return data
            let ptr := mload(0x40)

            // Perform the callcode
            success := callcode(gas(), CALL_CAIRO_PRECOMPILE, 0, add(callData, 0x20), mload(callData), ptr, 0)

            // Retrieve the size of the return data
            let size := returndatasize()

            // Store the size of the return data
            mstore(result, size)

            // Copy the return data
            returndatacopy(add(result, 0x20), 0, size)

            // Update the free memory pointer
            mstore(0x40, add(result, add(0x20, size)))
        }

        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }
}
