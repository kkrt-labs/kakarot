// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Counter} from "../src/PlainOpcodes/Counter.sol";
import {PlainOpcodes} from "../src/PlainOpcodes/PlainOpcodes.sol";

contract CounterScript is Script {
    Counter public counter;
    PlainOpcodes public plainOpcodes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey != 0, "PRIVATE_KEY must be set and non-zero");
        vm.startBroadcast(deployerPrivateKey);

        counter = new Counter();
        require(address(counter) != address(0), "Failed to deploy Counter");
        plainOpcodes = new PlainOpcodes(address(counter));
        require(address(plainOpcodes) != address(0), "Failed to deploy PlainOpcodes");
        bytes memory counterCode = type(Counter).creationCode;
        plainOpcodes.create(counterCode, 1);

        vm.stopBroadcast();
    }
}
