// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Contract for integration testing of EVM opcodes.
/// @author Kakarot9000
/// @dev Use this contract to call a contract from another contract
contract Caller {
    event Call(bool success, bytes returnData);

    function call(address target, bytes calldata payload) external {
        (bool success, bytes memory returnData) = address(target).call(payload);
        emit Call(success, returnData);
    }
}
