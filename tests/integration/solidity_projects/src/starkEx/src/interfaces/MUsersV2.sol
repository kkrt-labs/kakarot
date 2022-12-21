// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

abstract contract MUsersV2 {
    function registerUser(
        // NOLINT external-function.
        address ethKey,
        uint256 starkKey,
        bytes calldata signature
    ) public virtual;
}
