// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { BaseAuth } from "./BaseAuth.sol";

/// @title Gas Sponsor Invoker
/// @notice Invoker contract using EIP-3074 to sponsor gas for authorized transactions
contract GasSponsorInvoker is BaseAuth {
    /// @notice Executes a call authorized by an external account (EOA)
    /// @param authority The address of the authorizing external account
    /// @param commit A 32-byte value committing to transaction validity conditions
    /// @param v The recovery byte of the signature
    /// @param r Half of the ECDSA signature pair
    /// @param s Half of the ECDSA signature pair
    /// @param to The target contract address to call
    /// @param data The data payload for the call
    /// @return success True if the call was successful
    function sponsorCall(
        address authority,
        bytes32 commit,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address to,
        bytes calldata data
    ) external returns (bool success) {
        // Ensure the transaction is authorized by the signer
        require(authSimple(authority, commit, v, r, s), "Authorization failed");

        // Execute the call as authorized by the signer
        success = authCallSimple(to, data, 0, 0);
        require(success, "Call execution failed");
    }
}
