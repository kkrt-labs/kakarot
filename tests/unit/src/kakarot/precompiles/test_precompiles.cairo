// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq
from starkware.cairo.common.math import split_felt, assert_nn
from starkware.cairo.common.bool import FALSE, TRUE

// Local dependencies
from utils.utils import Helpers
from kakarot.constants import Constants
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.instructions.system_operations import SystemOperations
from kakarot.precompiles.precompiles import Precompiles
from tests.unit.helpers.helpers import TestHelpers

@external
func test__precompiles_should_throw_on_out_of_bounds{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(address: felt) {
    // When
    let result = Precompiles.run(
        address=address,
        calldata_len=0,
        calldata=cast(0, felt*),
        value=0,
        calling_context=cast(0, model.ExecutionContext*),
        return_data_len=0,
        return_data=cast(0, felt*),
    );

    return ();
}
