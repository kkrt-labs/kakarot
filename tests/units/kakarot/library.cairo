// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin

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

//
// Functions
//

func setup{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        # Load config
        import sys
        import time
        sys.path.append('.')
        from tests import load
        load("./tests/units/kakarot/config.yml", context)
    %}
    return ();
}

func prepare{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    test_context: TestContext
) {
    alloc_locals;

    // Extract context variables
    local admin;
    local anyone;
    %{
        ids.admin = context.signers.admin
        ids.anyone = context.signers.anyone
    %}

    // Instantiate yielder
    Kakarot.constructor(owner=admin);

    // Instantiate context, useful to avoid many hints in tests
    local signers: Signers = Signers(admin=admin, anyone=anyone);

    local mocks: Mocks = Mocks(
        );

    local context: TestContext = TestContext(signers=signers, mocks=mocks);
    return (test_context=context);
}
