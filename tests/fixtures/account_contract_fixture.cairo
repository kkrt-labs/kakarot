// SPDX-License-Identifier: MIT
// ! A fixture of the Account Contract class, used to test the upgradeability flow, where version = 001.000.000
%lang starknet

from kakarot.accounts.account_contract import (
    constructor,
    __validate__,
    __validate_declare__,
    __execute__,
    write_bytecode,
    bytecode_len,
    bytecode,
    write_storage,
    storage,
    get_nonce,
    set_nonce,
    get_evm_address,
    is_initialized,
)

// make sure the class hash is different
const SALT = 'salt';
