// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract Counter {
    uint256 public count;

    modifier greaterThanZero() {
        require(count > 0, "count should be strictly greater than 0");
        _;
    }

    constructor() {
        count = 0;
    }

    function inc() public {
        count += 1;
    }

    function dec() public greaterThanZero {
        count -= 1;
    }

    function decInPlace() public greaterThanZero {
        count--;
    }

    function decUnchecked() public {
        unchecked {
            count -= 1;
        }
    }

    function decUnsafe() public {
        count -= 1;
    }

    function reset() public {
        count = 0;
    }

    function incForLoop(uint256 iterations) public {
        count = 0;
        for (uint256 i = 0; i < iterations; i++) {
            count++;
        }
    }

    function incWhileLoop(uint256 iterations) public {
        count = 0;
        while (count < iterations) {
            count++;
        }
    }
}
