// SPDX-License-Identifier: MIT
// ! A fixture of the Account Contract class, used to test the upgradeability flow
%lang starknet

from kakarot.accounts.uninitialized_account import (
    constructor,
    __default__,
    __l1_default__,
    get_owner,
)

// make sure the class hash is different
const SALT = 'salt';
