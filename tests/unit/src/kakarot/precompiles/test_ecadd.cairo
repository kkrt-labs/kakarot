// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_add
from starkware.cairo.common.cairo_secp.bigint import BigInt3

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.ecadd import PrecompileEcAdd
from kakarot.model import model
from kakarot.memory import Memory
from kakarot.constants import Constants
from kakarot.stack import Stack
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.memory_operations import MemoryOperations
from kakarot.instructions.system_operations import SystemOperations, CallHelper, CreateHelper
from tests.unit.helpers.helpers import TestHelpers

const ECPOINT_BYTES_LEN = 32;

@external
func test__ecadd_impl{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) {
    // Given
    alloc_locals;

    let input_word0 = Helpers.load_word(ECPOINT_BYTES_LEN, calldata);
    let input_word1 = Helpers.load_word(ECPOINT_BYTES_LEN, calldata + ECPOINT_BYTES_LEN);
    let input_word2 = Helpers.load_word(ECPOINT_BYTES_LEN, calldata + ECPOINT_BYTES_LEN * 2);
    let input_word3 = Helpers.load_word(ECPOINT_BYTES_LEN, calldata + ECPOINT_BYTES_LEN * 3);
    let x0: BigInt3 = Helpers.to_bigint(input_word0);
    let y0: BigInt3 = Helpers.to_bigint(input_word1);
    let x1: BigInt3 = Helpers.to_bigint(input_word2);
    let y1: BigInt3 = Helpers.to_bigint(input_word3);

    let point0 = EcPoint(x0, y0);
    let point1 = EcPoint(x1, y1);
    let (expected_point: EcPoint) = ec_add(point0, point1);
    let expected_x = Helpers.bigint_to_felt(expected_point.x);
    let expected_y = Helpers.bigint_to_felt(expected_point.y);

    // When
    let (output_len, output: felt*, gas_cost) = PrecompileEcAdd.run(
        PrecompileEcAdd.PRECOMPILE_ADDRESS, calldata_len, calldata
    );
    let output_x = Helpers.load_word(ECPOINT_BYTES_LEN, output);
    let output_y = Helpers.load_word(ECPOINT_BYTES_LEN, output + ECPOINT_BYTES_LEN);

    // Then
    assert expected_x = output_x;
    assert expected_y = output_y;
    return ();
}
