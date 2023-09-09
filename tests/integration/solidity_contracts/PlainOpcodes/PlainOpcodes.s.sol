// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Counter} from "./Counter.sol";
import {PlainOpcodes} from "./PlainOpcodes.sol";

contract CounterScript is Script {
    Counter public counter;
    PlainOpcodes public plainOpcodes;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        counter = new Counter();
        plainOpcodes = new PlainOpcodes(address(counter));
        plainOpcodes.create(type(Counter).creationCode, 1);

        vm.stopBroadcast();
    }
}
