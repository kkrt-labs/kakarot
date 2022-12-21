// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

contract PublicInputOffsets {
    // The following constants are offsets of data expected in the public input.
    uint256 internal constant PUB_IN_GLOBAL_CONFIG_CODE_OFFSET = 0;
    uint256 internal constant PUB_IN_INITIAL_VALIDIUM_VAULT_ROOT_OFFSET = 1;
    uint256 internal constant PUB_IN_FINAL_VALIDIUM_VAULT_ROOT_OFFSET = 2;
    uint256 internal constant PUB_IN_INITIAL_ROLLUP_VAULT_ROOT_OFFSET = 3;
    uint256 internal constant PUB_IN_FINAL_ROLLUP_VAULT_ROOT_OFFSET = 4;
    uint256 internal constant PUB_IN_INITIAL_ORDER_ROOT_OFFSET = 5;
    uint256 internal constant PUB_IN_FINAL_ORDER_ROOT_OFFSET = 6;
    uint256 internal constant PUB_IN_GLOBAL_EXPIRATION_TIMESTAMP_OFFSET = 7;
    uint256 internal constant PUB_IN_VALIDIUM_VAULT_TREE_HEIGHT_OFFSET = 8;
    uint256 internal constant PUB_IN_ROLLUP_VAULT_TREE_HEIGHT_OFFSET = 9;
    uint256 internal constant PUB_IN_ORDER_TREE_HEIGHT_OFFSET = 10;
    uint256 internal constant PUB_IN_N_MODIFICATIONS_OFFSET = 11;
    uint256 internal constant PUB_IN_N_CONDITIONAL_TRANSFERS_OFFSET = 12;
    uint256 internal constant PUB_IN_N_ONCHAIN_VAULT_UPDATES_OFFSET = 13;
    uint256 internal constant PUB_IN_N_ONCHAIN_ORDERS_OFFSET = 14;
    uint256 internal constant PUB_IN_TRANSACTIONS_DATA_OFFSET = 15;

    uint256 internal constant PUB_IN_N_WORDS_PER_MODIFICATION = 3;
    uint256 internal constant PUB_IN_N_WORDS_PER_CONDITIONAL_TRANSFER = 1;
    uint256 internal constant PUB_IN_N_WORDS_PER_ONCHAIN_VAULT_UPDATE = 3;
    uint256 internal constant PUB_IN_N_MIN_WORDS_PER_ONCHAIN_ORDER = 3;

    // The following constants are offsets of data expected in the application data.
    uint256 internal constant APP_DATA_BATCH_ID_OFFSET = 0;
    uint256 internal constant APP_DATA_PREVIOUS_BATCH_ID_OFFSET = 1;
    uint256 internal constant APP_DATA_TRANSACTIONS_DATA_OFFSET = 2;

    uint256 internal constant APP_DATA_N_WORDS_PER_CONDITIONAL_TRANSFER = 2;
}
