// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title BaseAuth
/// @author Anna Carroll <https://github.com/anna-carroll/3074>
abstract contract BaseAuth {
    /// @notice magic byte to disambiguate EIP-3074 signature payloads
    uint8 constant MAGIC = 0x04;

    /// @notice produce a digest for the authorizer to sign
    /// @param commit - any 32-byte value used to commit to transaction validity conditions
    /// @param nonce - signer's current nonce
    /// @return digest - sign the `digest` to authorize the invoker to execute the `calls`
    /// @dev signing `digest` authorizes this contact to execute code on behalf of the signer
    ///      the logic of the inheriting contract should encode rules which respect the information within `commit`
    /// @dev the authorizer includes `commit` in their signature to ensure the authorized contract will only execute intended actions(s).
    ///      the Invoker logic MUST implement constraints on the contract execution based on information in the `commit`;
    ///      otherwise, any EOA that signs an AUTH for the Invoker will be compromised
    /// @dev per EIP-3074, digest = keccak256(MAGIC || paddedChainId || paddedNonce || paddedInvokerAddress || commit)
    function getDigest(bytes32 commit, uint256 nonce) public view returns (bytes32 digest) {
        digest =
            keccak256(abi.encodePacked(MAGIC, bytes32(block.chainid), bytes32(nonce), bytes32(uint256(uint160(address(this)))), commit));
    }

    function authSimple(address authority, bytes32 commit, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool success)
    {
        bytes memory authArgs = abi.encodePacked(yParity(v), r, s, commit);
        assembly {
            success := auth(authority, add(authArgs, 0x20), mload(authArgs))
        }
    }

    function authCallSimple(address to, bytes memory data, uint256 value, uint256 gasLimit)
        internal
        returns (bool success)
    {
        assembly {
            success := authcall(gasLimit, to, value, add(data, 0x20), mload(data), 0, 0)
        }
    }

    /// @dev Internal helper to convert `v` to `yParity` for `AUTH`
    function yParity(uint8 v) private pure returns (uint8 yParity_) {
        assembly {
            switch lt(v, 35)
            case true { yParity_ := eq(v, 28) }
            default { yParity_ := mod(sub(v, 35), 2) }
        }
    }
}
