%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc

from utils.utils import Helpers
from kakarot.precompiles.identity import PrecompileIdentity
from tests.utils.helpers import TestHelpers

func test__datacopy_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}() {
    // Given # 1
    alloc_locals;
    local calldata_len: felt;
    let (calldata: felt*) = alloc();
    %{
        ids.calldata_len = len(program_input["calldata"]);
        segments.write_arg(ids.calldata, program_input["calldata"]);
    %}

    // When
    let result = PrecompileIdentity.run(
        PrecompileIdentity.PRECOMPILE_ADDRESS, calldata_len, calldata
    );

    TestHelpers.assert_array_equal(
        array_0_len=calldata_len,
        array_0=calldata,
        array_1_len=result.output_len,
        array_1=result.output,
    );
    return ();
}
