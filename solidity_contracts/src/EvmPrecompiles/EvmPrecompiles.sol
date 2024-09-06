// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @title EVM Precompiles Integration
/// @notice Contract for integration testing of EVM precompiles.
/// @dev Implements functions for ECADD and ECMUL precompiles.
contract EvmPrecompiles {
    /// @dev Address of the ECADD precompile
    address private constant ECADD_PRECOMPILE = address(0x06);
    /// @dev Address of the ECMUL precompile
    address private constant ECMUL_PRECOMPILE = address(0x07);

    /// @dev Gas cost for ECADD operation
    uint256 private constant ECADD_GAS = 150;
    /// @dev Gas cost for ECMUL operation
    uint256 private constant ECMUL_GAS = 6000;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {}

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS FOR PRECOMPILES
    //////////////////////////////////////////////////////////////*/
    /// @notice Performs elliptic curve addition
    /// @param x1 X coordinate of the first point
    /// @param y1 Y coordinate of the first point
    /// @param x2 X coordinate of the second point
    /// @param y2 Y coordinate of the second point
    /// @return x X coordinate of the result point
    /// @return y Y coordinate of the result point
    function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) public view returns (uint256 x, uint256 y) {
        bytes memory input = abi.encodePacked(x1, y1, x2, y2);
        (bool success, bytes memory result) = ECADD_PRECOMPILE.staticcall{gas: ECADD_GAS}(input);
        require(success, "ECADD precompile call failed");
        return abi.decode(result, (uint256, uint256));
    }

    /// @notice Performs elliptic curve scalar multiplication
    /// @param x1 X coordinate of the point
    /// @param y1 Y coordinate of the point
    /// @param s Scalar for multiplication
    /// @return x X coordinate of the result point
    /// @return y Y coordinate of the result point
    function ecMul(uint256 x1, uint256 y1, uint256 s) public view returns (uint256 x, uint256 y) {
        bytes memory input = abi.encodePacked(x1, y1, s);
        (bool success, bytes memory result) = ECMUL_PRECOMPILE.staticcall{gas: ECMUL_GAS}(input);
        require(success, "ECMUL precompile call failed");
        return abi.decode(result, (uint256, uint256));
    }
}
