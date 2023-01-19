pragma solidity 0.8.10;

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
        assembly {
            counterSize := extcodesize(target)
            expectedResult := mload(0x40)
            mstore(
                0x40,
                add(
                    expectedResult,
                    and(add(add(counterSize, 0x20), 0x1f), not(0x1f))
                )
            )
            mstore(expectedResult, counterSize)
            extcodecopy(target, add(expectedResult, 0x20), 0, counterSize)
        }

        bytes memory bytecode = plainOpcodes.opcodeExtCodeCopy(0, counterSize);
        assertEq0(bytecode, expectedResult);
    }
}
