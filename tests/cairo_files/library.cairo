// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from kakarot.library import Kakarot

//
// Structs
//

struct Signers {
    admin: felt,
    anyone: felt,
}

struct Mocks {
}

struct TestContext {
    signers: Signers,
    mocks: Mocks,
}
