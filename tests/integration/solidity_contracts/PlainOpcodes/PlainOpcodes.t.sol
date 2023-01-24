pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {PlainOpcodes} from "./PlainOpcodes.sol";
import {Counter} from "./Counter.sol";

contract PlainOpcodesTest is Test {
    PlainOpcodes plainOpcodes;
    Counter counter;

    function setUp() public {
        counter = new Counter();
        plainOpcodes = new PlainOpcodes(address(counter));
    }

    function testOpcodeExtCodeCopyReturnsCounterCode(
        uint256 offset,
        uint256 size
    ) public {
        address target = address(counter);
        uint256 counterSize;
        assembly {
            counterSize := extcodesize(target)
        }
        vm.assume(size < counterSize + 1);
        vm.assume(offset < counterSize);
        bytes memory expectedResult;
        // see https://docs.soliditylang.org/en/v0.8.17/assembly.html#example
        assembly {
            counterSize := extcodesize(target)
            // get a free memory location to write result into
            expectedResult := mload(0x40)
            // update free memory pointer: write at 0x40 an empty memory address
            mstore(
                0x40,
                add(
                    expectedResult,
                    and(add(add(counterSize, 0x20), 0x1f), not(0x1f))
                )
            )
            // store the size of the result at expectedResult
            // a bytes array stores its size in the first word
            mstore(expectedResult, counterSize)
            // actually copy the counter code from offset expectedResult + 0x20 (size location)
            extcodecopy(target, add(expectedResult, 0x20), 0, counterSize)
        }

        bytes memory bytecode = plainOpcodes.opcodeExtCodeCopy(0, counterSize);
        assertEq0(bytecode, expectedResult);
    }
}
