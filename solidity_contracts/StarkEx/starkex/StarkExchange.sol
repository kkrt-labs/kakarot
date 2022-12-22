// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../interfaces/MainDispatcher.sol";

contract StarkExchange is MainDispatcher {
    string public constant VERSION = "4.5.1";

    // Salt for a 8 bit unique spread of all relevant selectors. Pre-caclulated.
    // ---------- The following code was auto-generated. PLEASE DO NOT EDIT. ----------
    uint256 constant MAGIC_SALT = 1527414;
    uint256 constant IDX_MAP_0 = 0x2010501100000010050000002511000000220005410030200200200000552010;
    uint256 constant IDX_MAP_1 = 0x3000030005000050020012003000010604300000002420501003000010000300;
    uint256 constant IDX_MAP_2 = 0x1003112030002130000200100020000320202001020001001000040200200020;
    uint256 constant IDX_MAP_3 = 0x2000000050000012000013100002002002032050020002020002050000201003;

    // ---------- End of auto-generated code. ----------

    function getNumSubcontracts() internal pure override returns (uint256) {
        return 6;
    }

    function magicSalt() internal pure override returns (uint256) {
        return MAGIC_SALT;
    }

    function handlerMapSection(uint256 section) internal pure override returns (uint256) {
        if (section == 0) {
            return IDX_MAP_0;
        } else if (section == 1) {
            return IDX_MAP_1;
        } else if (section == 2) {
            return IDX_MAP_2;
        } else if (section == 3) {
            return IDX_MAP_3;
        }
        revert("BAD_IDX_MAP_SECTION");
    }

    function expectedIdByIndex(uint256 index) internal pure override returns (string memory id) {
        if (index == 1) {
            id = "StarkWare_AllVerifiers_2022_2";
        } else if (index == 2) {
            id = "StarkWare_TokensAndRamping_2022_2";
        } else if (index == 3) {
            id = "StarkWare_StarkExState_2022_5";
        } else if (index == 4) {
            id = "StarkWare_ForcedActions_2022_3";
        } else if (index == 5) {
            id = "StarkWare_OnchainVaults_2022_2";
        } else if (index == 6) {
            id = "StarkWare_ProxyUtils_2022_2";
        } else {
            revert("UNEXPECTED_INDEX");
        }
    }

    function initializationSentinel() internal view override {
        string memory REVERT_MSG = "INITIALIZATION_BLOCKED";
        // This initializer sets roots etc. It must not be applied twice.
        // I.e. it can run only when the state is still empty.
        require(validiumVaultRoot == 0, REVERT_MSG);
        require(validiumTreeHeight == 0, REVERT_MSG);
        require(rollupVaultRoot == 0, REVERT_MSG);
        require(rollupTreeHeight == 0, REVERT_MSG);
        require(orderRoot == 0, REVERT_MSG);
        require(orderTreeHeight == 0, REVERT_MSG);
    }
}
