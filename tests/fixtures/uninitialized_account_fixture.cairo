// SPDX-License-Identifier: MIT
// ! A fixture of the Account Contract class, used to test the upgradeability flow, where version = 001.000.000
%lang starknet

from kakarot.accounts.uninitialized_account import (
    constructor,
    __default__,
    __l1_default__,
    set_implementation,
    get_owner,
)

// make sure the class hash is different
const SALT = 'salt';
