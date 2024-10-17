// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {PragmaCaller} from "../src/CairoPrecompiles/PragmaCaller.sol";

contract PragmaCallerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 pragmaOracleAddress = vm.envUint("PRAGMA_ORACLE_ADDRESS");
        uint256 pragmaSummaryStatsAddress = vm.envUint("PRAGMA_SUMMARY_STATS_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        PragmaCaller pragmaCaller = new PragmaCaller(pragmaOracleAddress, pragmaSummaryStatsAddress);

        vm.stopBroadcast();
    }
}
