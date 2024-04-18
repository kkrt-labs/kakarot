// SPDX-License-Identifier: MIT
// ! A fixture of the Account Contract class, used to test the upgradeability flow, where version = 001.000.000
%lang starknet

from kakarot.accounts.account_contract import (
    constructor,
    initialize,
    version,
    get_evm_address,
    is_initialized,
    __validate__,
    __validate_declare__,
    __execute__,
    write_bytecode,
    bytecode,
    bytecode_len,
    write_storage,
    storage,
    get_nonce,
    set_nonce,
)

// make sure the class hash is different
const SALT = 'salt';
