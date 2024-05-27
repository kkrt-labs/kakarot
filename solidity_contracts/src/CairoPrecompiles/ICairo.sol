// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

/// @dev The Cairo precompile contract's address.
address constant CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075001;

/// @notice Solidity interface that allows developers to interact with Cairo contracts and classes. This interface can be  the `call_contract` and `library_call`
interface ICairo {
    /// @dev Call a Cairo contract deployed on the Starknet appchain
    function call_contract(uint256 contractAddress, uint256 functionSelector, uint256[] memory data) external returns (bytes memory);
    /// @dev Call a Cairo class declared on the Starknet appchain
    function library_call(uint256 classHash, uint256 functionSelector, uint256[] memory data) external returns (bytes memory);
}
