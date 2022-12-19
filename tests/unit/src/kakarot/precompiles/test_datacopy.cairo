// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_sub
from starkware.cairo.common.math import assert_nn
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

// Local dependencies
from utils.utils import Helpers
from kakarot.precompiles.datacopy import PrecompileDataCopy
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.constants import Constants, blockhash_registry_address
from kakarot.execution_context import ExecutionContext
from kakarot.instructions.block_information import BlockInformation
from tests.unit.helpers.helpers import TestHelpers

@external
func test__datacopy{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(calldata_len: felt, calldata: felt*) -> (return_data_len: felt, return_data: felt*) {
    // Given # 1
    alloc_locals;
    let (bytecode) = alloc();

    local call_context: model.CallContext* = new model.CallContext(
        bytecode=bytecode, bytecode_len=0, calldata=calldata, calldata_len=calldata_len, value=0
        );

    // let (return_data) = alloc();
    // let return_data_len: felt = 32;
    // filling at return_data + 1 because first first felt is return_data offset
    // TestHelpers.array_fill(return_data + 1, return_data_len, 0xFF);

    let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);

    // When
    let result = PrecompileDataCopy.run(ctx);

    // Then

    // TODO:  assert gas stuff
    return (return_data_len=result.return_data_len, return_data=result.return_data);
}
