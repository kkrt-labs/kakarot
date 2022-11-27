// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256, uint256_eq
from starkware.cairo.common.math import split_felt

// Internal dependencies
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.model import model
from utils.utils import Helpers
from tests.utils.model import EVMTestCase

namespace TestHelpers {
    func init_context{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
    }() -> model.ExecutionContext* {
        alloc_locals;
        let (bytecode) = alloc();
        assert [bytecode] = 00;
        tempvar bytecode_len = 1;
        let (calldata) = alloc();
        assert [calldata] = '';
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode, bytecode_len=bytecode_len, calldata=calldata, calldata_len=1, value=0
        );
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);
        return ctx;
    }

    func init_context_with_stack{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
    }(stack: model.Stack*) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context();
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }
}
