// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.datacopy import PrecompileDataCopy
from tests.utils.helpers import TestHelpers

@external
func test__datacopy_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // Given # 1
    alloc_locals;
    // When
    let result = PrecompileDataCopy.run(
        PrecompileDataCopy.PRECOMPILE_ADDRESS, calldata_len, calldata
    );

    TestHelpers.assert_array_equal(
        array_0_len=calldata_len,
        array_0=calldata,
        array_1_len=result.output_len,
        array_1=result.output,
    );
    return ();
}
