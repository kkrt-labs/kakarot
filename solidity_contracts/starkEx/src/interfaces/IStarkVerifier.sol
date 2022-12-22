// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

interface IStarkVerifier {
    function verifyProof(
        uint256[] calldata proofParams,
        uint256[] calldata proof,
        uint256[] calldata publicInput
    ) external;
}
