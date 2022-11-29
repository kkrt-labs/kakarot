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
    }(bytecode_len: felt, bytecode: felt*) -> model.ExecutionContext* {
        alloc_locals;

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
    }(bytecode_len: felt, bytecode: felt*, stack: model.Stack*) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context(bytecode_len, bytecode);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice Init an execution context where bytecode has "bytecode_count" entries of "value".
    func init_context_with_bytecode{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*
    }(bytecode_count: felt, value: felt) -> model.ExecutionContext* {
        alloc_locals;
        
        let (bytecode) = alloc();
        _fill_bytecode_with_values(bytecode, bytecode_count, value);

        return TestHelpers.init_context(bytecode_count, bytecode);
    }

    // @notice Fill a bytecode array with "bytecode_count" entries of "value".
    // ex: _fill_bytecode_with_values(bytecode, 2, 0xFF)
    // bytecode will be equal to [0xFF, 0xFF]
    func _fill_bytecode_with_values(bytecode: felt*, bytecode_count: felt, value: felt) {
        assert bytecode[bytecode_count - 1] = value;

        if (bytecode_count - 1 == 0) {
            return ();
        }

        _fill_bytecode_with_values(bytecode, bytecode_count - 1, value);

        return ();
    }
    
    func assert_stack_last_element_contains{range_check_ptr}(stack: model.Stack*, value: felt) {
        let (stack,index0) = Stack.peek(stack, 0);
        assert index0 = Uint256(value, 0);

        return ();
    }
}
