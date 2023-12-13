// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from kakarot.constants import Constants
from kakarot.evm import EVM
from kakarot.model import model
from tests.utils.helpers import TestHelpers
from utils.utils import Helpers

@external
func test__jump{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
}(bytecode_len: felt, bytecode: felt*, jumpdest: felt) -> (
    pc: felt, return_data_len: felt, return_data: felt*
) {
    alloc_locals;
    let evm = TestHelpers.init_evm_with_bytecode(bytecode_len, bytecode);
    let evm = EVM.jump(evm, jumpdest);
    return (evm.program_counter, evm.return_data_len, evm.return_data);
}
