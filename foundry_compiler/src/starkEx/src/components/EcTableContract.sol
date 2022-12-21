// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

contract EcTableContract {
    /*
      Given n 512 bit words, performs n lookups.
      The lookups are done for the first byte of each 512 bit word in the input.

      The result of each lookup is 512 bits so the input and the output are of the same size.

      This function assumes that the deployment script appends an 0x4000 bytes lookup table to the
      end of the code in the contract.
    */
    fallback() external {
        assembly {
            let tableOffset := sub(
                codesize(),
                // table size=
                0x4000
            )

            // The lookup loop is unrolled 33 times as it saves ~90k gas in the expected use case.
            // The first lookup index is at byte offset shl(6, shr(0xf8, calldataload(0x0))
            // into the lookup table.
            // codecopy(...) copies the 64 bytes at that offset into the output array.
            codecopy(0x0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x0)))), 0x40)
            codecopy(0x40, add(tableOffset, shl(6, shr(0xf8, calldataload(0x40)))), 0x40)
            codecopy(0x80, add(tableOffset, shl(6, shr(0xf8, calldataload(0x80)))), 0x40)
            codecopy(0xc0, add(tableOffset, shl(6, shr(0xf8, calldataload(0xc0)))), 0x40)
            codecopy(0x100, add(tableOffset, shl(6, shr(0xf8, calldataload(0x100)))), 0x40)
            codecopy(0x140, add(tableOffset, shl(6, shr(0xf8, calldataload(0x140)))), 0x40)
            codecopy(0x180, add(tableOffset, shl(6, shr(0xf8, calldataload(0x180)))), 0x40)
            codecopy(0x1c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x1c0)))), 0x40)
            codecopy(0x200, add(tableOffset, shl(6, shr(0xf8, calldataload(0x200)))), 0x40)
            codecopy(0x240, add(tableOffset, shl(6, shr(0xf8, calldataload(0x240)))), 0x40)
            codecopy(0x280, add(tableOffset, shl(6, shr(0xf8, calldataload(0x280)))), 0x40)
            codecopy(0x2c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x2c0)))), 0x40)
            codecopy(0x300, add(tableOffset, shl(6, shr(0xf8, calldataload(0x300)))), 0x40)
            codecopy(0x340, add(tableOffset, shl(6, shr(0xf8, calldataload(0x340)))), 0x40)
            codecopy(0x380, add(tableOffset, shl(6, shr(0xf8, calldataload(0x380)))), 0x40)
            codecopy(0x3c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x3c0)))), 0x40)
            codecopy(0x400, add(tableOffset, shl(6, shr(0xf8, calldataload(0x400)))), 0x40)
            codecopy(0x440, add(tableOffset, shl(6, shr(0xf8, calldataload(0x440)))), 0x40)
            codecopy(0x480, add(tableOffset, shl(6, shr(0xf8, calldataload(0x480)))), 0x40)
            codecopy(0x4c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x4c0)))), 0x40)
            codecopy(0x500, add(tableOffset, shl(6, shr(0xf8, calldataload(0x500)))), 0x40)
            codecopy(0x540, add(tableOffset, shl(6, shr(0xf8, calldataload(0x540)))), 0x40)
            codecopy(0x580, add(tableOffset, shl(6, shr(0xf8, calldataload(0x580)))), 0x40)
            codecopy(0x5c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x5c0)))), 0x40)
            codecopy(0x600, add(tableOffset, shl(6, shr(0xf8, calldataload(0x600)))), 0x40)
            codecopy(0x640, add(tableOffset, shl(6, shr(0xf8, calldataload(0x640)))), 0x40)
            codecopy(0x680, add(tableOffset, shl(6, shr(0xf8, calldataload(0x680)))), 0x40)
            codecopy(0x6c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x6c0)))), 0x40)
            codecopy(0x700, add(tableOffset, shl(6, shr(0xf8, calldataload(0x700)))), 0x40)
            codecopy(0x740, add(tableOffset, shl(6, shr(0xf8, calldataload(0x740)))), 0x40)
            codecopy(0x780, add(tableOffset, shl(6, shr(0xf8, calldataload(0x780)))), 0x40)
            codecopy(0x7c0, add(tableOffset, shl(6, shr(0xf8, calldataload(0x7c0)))), 0x40)
            codecopy(0x800, add(tableOffset, shl(6, shr(0xf8, calldataload(0x800)))), 0x40)

            // If the calldatasize > 0x40 * 33, do the remaining lookups using a loop.
            for {
                let offset := 0x840
            } lt(offset, calldatasize()) {
                offset := add(offset, 0x40)
            } {
                codecopy(offset, add(tableOffset, shl(6, shr(0xf8, calldataload(offset)))), 0x40)
            }

            return(0, calldatasize())
        }
    }
}
