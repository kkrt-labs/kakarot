// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

/// @notice A contract that performs various call types to the Kakarot MulticallCairo precompile.
/// @dev Only meant to test the MulticallCairo precompile when called from a Solidity Contract.
contract MulticallCairoPrecompileTest {
    /// @dev The cairo contract to call
    uint256 immutable cairoCounter;

    /// @dev The cairo function selector to call - `inc`
    uint256 constant FUNCTION_SELECTOR_INC = uint256(keccak256("inc")) % 2 ** 250;

    constructor(uint256 cairoContractAddress) {
        cairoCounter = cairoContractAddress;
    }

    /// @notice Calls the Cairo contract to increment its internal counter in a batch of multiple calls
    function incrementCairoCounterBatch(uint32 n_calls) external {
        CairoLib.CairoCall[] memory calls = new CairoLib.CairoCall[](n_calls);
        for (uint32 i = 0; i < n_calls; i++) {
            calls[i] = CairoLib.CairoCall({
                contractAddress: cairoCounter,
                functionSelector: FUNCTION_SELECTOR_INC,
                data: new uint256[](0)
            });
        }
        CairoLib.multicallCairo(calls);
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    function incrementCairoCounter() external {
        uint256[] memory data = new uint256[](0);
        Internals.callCairo(cairoCounter, "inc", data);
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev The delegatecall preserves the caller's context, so the caller's address will
    /// be the caller of this function.
    /// @dev Should always fail, as MulticallCairo does not support delegatecalls.
    function incrementCairoCounterDelegatecall() external {
        uint256[] memory data = new uint256[](0);
        Internals.delegatecallCairo(cairoCounter, "inc", data);
    }

    /// @notice Calls the Cairo contract to increment its internal counter
    /// @dev Called with a regular call, the caller's address will be this contract's address
    /// @dev Should always fail, as MulticallCairo does not support callcode.
    function incrementCairoCounterCallcode() external {
        uint256[] memory data = new uint256[](0);
        Internals.callcodeCairo(cairoCounter, "inc", data);
    }
}

library Internals {
    /// @dev The Batch Cairo precompile contract's address.
    address constant BATCH_CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075003;

    struct CairoCall {
        uint256 contractAddress;
        uint256 functionSelector;
        uint256[] data;
    }

    function batchCallCairo(CairoCall[] memory calls) internal returns (bytes memory) {
        uint256 n_calls = calls.length;
        bytes memory callData = abi.encode(n_calls);

        for (uint32 i = 0; i < n_calls; i++) {
            bytes memory encodedCall = abi.encode(calls[i].contractAddress, calls[i].functionSelector, calls[i].data);
            callData = bytes.concat(callData, encodedCall);
        }

        (bool success, bytes memory result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function callCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData =
            bytes.concat(abi.encode(uint256(1)), abi.encode(contractAddress, functionSelector, data));

        (bool success, bytes memory result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function delegatecallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData =
            bytes.concat(abi.encode(uint256(1)), abi.encode(contractAddress, functionSelector, data));

        bool success;
        bytes memory result;

        (success, result) = BATCH_CAIRO_PRECOMPILE_ADDRESS.delegatecall(callData);

        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        return result;
    }

    function callcodeCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        bytes memory callData =
            bytes.concat(abi.encode(uint256(1)), abi.encode(contractAddress, functionSelector, data));

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
}
