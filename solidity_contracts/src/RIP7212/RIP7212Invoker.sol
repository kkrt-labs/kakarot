// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract RIP7212Invoker  {

    address constant P256_VERIFY = 0x0000000000000000000000000000000000000100;

    function p256verify (bytes32 msg_hash, bytes32 r, bytes32 s, bytes32 x, bytes32 y) public view returns (bool) {
        assembly {
            let pointer := mload(0x40)

            // Load msg_hash, r, s, x, y into memory
            mstore(pointer, msg_hash)
            mstore(add(pointer, 0x20), r)
            mstore(add(pointer, 0x40), s)
            mstore(add(pointer, 0x60), x)
            mstore(add(pointer, 0x80), y)

            // Staticcall into the precompile, revert if it fails
            if iszero(staticcall(not(0), P256_VERIFY, pointer, 0xA0, pointer, 0x20)) {
                revert(0, 0)
            }

            // If the precompile returns no data, return false
            let size := returndatasize()
            if iszero(size) {
                mstore(pointer, 0)
                return(pointer, 0x20)
            }

            // Otherwise return the data.
            returndatacopy(pointer, 0, size)
            return(pointer, size)
        }
    }
}
