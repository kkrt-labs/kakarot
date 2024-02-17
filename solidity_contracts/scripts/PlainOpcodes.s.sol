// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Counter} from "../src/PlainOpcodes/Counter.sol";
import {PlainOpcodes} from "../src/PlainOpcodes/PlainOpcodes.sol";

contract CounterScript is Script {
    function run() external {
        Counter counter = new Counter();
        PlainOpcodes plainOpcodes = new PlainOpcodes(address(counter));
        plainOpcodes.create(type(Counter).creationCode, 1);
    }
}
