// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/// @notice A contract that performs various call types to the Kakarot MulticallCairo precompile.
/// @dev Only meant to test the MulticallCairo precompile when called from a Solidity Contract.
contract MulticallCairoCounterCaller {
    using MulticallCairoLib for uint256;

    /// @dev The cairo contract to call
    uint256 immutable cairoCounter;

    /// @dev The cairo function selector to call - `inc`
    uint256 constant FUNCTION_SELECTOR_INC = uint256(keccak256("inc")) % 2 ** 250;

    /// @dev The cairo function selector to call - `set_counter`
    uint256 constant FUNCTION_SELECTOR_SET_COUNTER = uint256(keccak256("set_counter")) % 2 ** 250;

    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        cairoCounter.callCairo("inc");
    }

    /// @notice Calls the Cairo contract to increment its internal counter in a batch of multiple calls
    function incrementCairoCounterBatch(uint32 n_calls) external {
        uint256[][] memory calls = new uint256[][](n_calls);
        for (uint32 i = 0; i < n_calls; i++) {
            calls[i] = new uint256[](3);
            calls[i][0] = cairoCounter;
            calls[i][1] = FUNCTION_SELECTOR_INC;
            calls[i][2] = 0; // Length of the empty calldata array
                // No data because len = 0
        }
        MulticallCairoLib.batchCallCairo(calls);
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev The delegatecall preserves the caller's context, so the caller's address will
    /// be the caller of this function.
    /// @dev Should always fail, as MulticallCairo does not support delegatecalls.
    function incrementCairoCounterDelegatecall() external {
        cairoCounter.delegatecallCairo("inc");
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev Called with a regular call, the caller's address will be this contract's address
    /// @dev Should always fail, as MulticallCairo does not support callcode.
    function incrementCairoCounterCallcode() external {
        cairoCounter.callcodeCairo("inc");
    }
}

library MulticallCairoLib {
    /// @dev The Batch Cairo precompile contract's address.
    address constant BATCH_CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075003;

    function batchCallCairo(uint256[][] memory calls) internal returns (bytes memory) {
        uint32 n_calls = uint32(calls.length);
        bytes4 selector = bytes4(keccak256("call_contract(bytes4,uint256,uint256,uint256[])"));
        bytes memory callData = abi.encodePacked(selector, bytes4(n_calls));

        for (uint32 i = 0; i < n_calls; i++) {
            require(calls[i].length >= 3, "Invalid call format");
            uint256 contractAddress = calls[i][0];
            uint256 functionSelector = calls[i][1];
            uint256 dataLength = calls[i][2];
            uint256[] memory data = new uint256[](dataLength);
            for (uint256 j = 0; j < dataLength; j++) {
                data[j] = calls[i][j + 3];
            }
            bytes memory encodedCall = abi.encode(contractAddress, functionSelector, data);
            callData = bytes.concat(callData, encodedCall);
        }

        (bool success, bytes memory result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function callCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        bytes4 selector = bytes4(keccak256("call_contract(bytes4,uint256,uint256,uint256[])"));
        bytes memory callData =
            abi.encodePacked(selector, bytes4(uint32(1)), abi.encode(contractAddress, functionSelector, data));

        (bool success, bytes memory result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function callCairo(uint256 contractAddress, uint256 functionSelector) internal returns (bytes memory) {
        uint256[] memory data = new uint256[](0);
        return callCairo(contractAddress, functionSelector, data);
    }

    function callCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callCairo(contractAddress, functionSelector, data);
    }

    function callCairo(uint256 contractAddress, string memory functionName) internal returns (bytes memory) {
        uint256[] memory data = new uint256[](0);
        return callCairo(contractAddress, functionName, data);
    }

    function delegatecallCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        bytes4 selector = bytes4(keccak256("call_contract(bytes4,uint256,uint256,uint256[])"));
        bytes memory callData =
            abi.encodePacked(selector, bytes4(uint32(1)), abi.encode(contractAddress, functionSelector, data));

        bool success;
        bytes memory result;

        (success, result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.delegatecall(callData);

        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function delegatecallCairo(uint256 contractAddress, uint256 functionSelector) internal returns (bytes memory) {
        uint256[] memory data = new uint256[](0);
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    function delegatecallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    function delegatecallCairo(uint256 contractAddress, string memory functionName) internal returns (bytes memory) {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    function callcodeCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        bytes4 selector = bytes4(keccak256("call_contract(bytes4,uint256,uint256,uint256[])"));
        bytes memory callData =
            abi.encodePacked(selector, bytes4(uint32(1)), abi.encode(contractAddress, functionSelector, data));

        bool success;
        bytes memory result;

        // Use inline assembly for callcode
        assembly {
            // Allocate memory for the return data
            let ptr := mload(0x40)

            // Perform the callcode
            success := callcode(gas(), BATCH_CAIRO_PRECOMPILE_ADDRESS, 0, add(callData, 0x20), mload(callData), ptr, 0)

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

    function callcodeCairo(uint256 contractAddress, string memory functionName) internal returns (bytes memory) {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callcodeCairo(contractAddress, functionSelector, data);
    }
}
