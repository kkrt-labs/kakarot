// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_add,
    uint256_eq,
    assert_uint256_eq,
)

// Internal dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.utils import Helpers

namespace TestHelpers {
    func init_context_at_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        bytecode_len: felt,
        bytecode: felt*,
        starknet_contract_address: felt,
        evm_contract_address: felt,
    ) -> model.ExecutionContext* {
        alloc_locals;

        let (calldata) = alloc();
        assert [calldata] = '';
        let root_context = ExecutionContext.init_empty();
        tempvar address = new model.Address(starknet_contract_address, evm_contract_address);
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=calldata,
            calldata_len=1,
            value=0,
            gas_limit=Constants.TRANSACTION_GAS_LIMIT,
            gas_price=0,
            origin=0,
            calling_context=root_context,
            address=address,
            read_only=FALSE,
            is_create=FALSE,
        );
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);
        return ctx;
    }

    func init_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*) -> model.ExecutionContext* {
        return init_context_at_address(bytecode_len, bytecode, 0, 0);
    }

    func init_context_with_stack{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*, stack: model.Stack*) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context(bytecode_len, bytecode);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func init_context_at_address_with_stack{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        starknet_contract_address: felt,
        evm_contract_address: felt,
        bytecode_len: felt,
        bytecode: felt*,
        stack: model.Stack*,
    ) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context_at_address(
            bytecode_len, bytecode, starknet_contract_address, evm_contract_address
        );
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice Init an execution context where bytecode has "bytecode_count" entries of "value".
    func init_context_with_bytecode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_count: felt, value: felt) -> model.ExecutionContext* {
        alloc_locals;

        let (bytecode) = alloc();
        array_fill(bytecode, bytecode_count, value);

        return init_context(bytecode_count, bytecode);
    }

    func init_context_with_return_data{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        bytecode_len: felt, bytecode: felt*, return_data_len: felt, return_data: felt*
    ) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context(bytecode_len, bytecode);
        let ctx = ExecutionContext.stop(ctx, return_data_len, return_data, FALSE);
        return ctx;
    }

    // @notice Fill a bytecode array with "bytecode_count" entries of "value".
    // ex: array_fill(bytecode, 2, 0xFF)
    // bytecode will be equal to [0xFF, 0xFF]
    func array_fill(bytecode: felt*, bytecode_count: felt, value: felt) {
        assert bytecode[bytecode_count - 1] = value;

        if (bytecode_count - 1 == 0) {
            return ();
        }

        array_fill(bytecode, bytecode_count - 1, value);

        return ();
    }

    // @notice Push n element-array starting from a specific value into the stack one at a time
    // ex: If n = 3 and start = Uint256(0, 0),
    // resulting stack elements will be [ Uint256(2, 0) ]
    //                                  [ Uint256(1, 0) ]
    //                                  [ Uint256(0, 0) ]
    func push_elements_in_range_to_stack{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(start: Uint256, n: felt, stack: model.Stack*) -> model.Stack* {
        alloc_locals;
        if (n == 0) {
            return stack;
        }

        uint256_check(start);
        let updated_stack: model.Stack* = Stack.push(stack, start);
        let (local element: Uint256, _) = uint256_add(start, Uint256(1, 0));
        return push_elements_in_range_to_stack(element, n - 1, updated_stack);
    }

    func assert_stack_last_element_contains_uint256{range_check_ptr}(
        stack: model.Stack*, value: Uint256
    ) {
        let (stack, result) = Stack.peek(stack, 0);
        assert_uint256_eq(result, value);

        return ();
    }

    func assert_stack_len_16bytes_equal{range_check_ptr}(stack: model.Stack*, len: felt) {
        assert stack.len_16bytes / 2 = len;

        return ();
    }

    func assert_array_equal(array_0_len: felt, array_0: felt*, array_1_len: felt, array_1: felt*) {
        assert array_0_len = array_1_len;
        if (array_0_len == 0) {
            return ();
        }
        assert [array_0] = [array_1];
        return assert_array_equal(array_0_len - 1, array_0 + 1, array_1_len - 1, array_1 + 1);
    }

    func assert_call_context_equal(
        call_context_0: model.CallContext*, call_context_1: model.CallContext*
    ) {
        assert call_context_0.value = call_context_1.value;
        assert_array_equal(
            call_context_0.bytecode_len,
            call_context_0.bytecode,
            call_context_1.bytecode_len,
            call_context_1.bytecode,
        );
        assert_array_equal(
            call_context_0.calldata_len,
            call_context_0.calldata,
            call_context_1.calldata_len,
            call_context_1.calldata,
        );
        return ();
    }

    func assert_execution_context_equal(
        ctx_0: model.ExecutionContext*, ctx_1: model.ExecutionContext*
    ) {
        let is_context_0_root = ExecutionContext.is_empty(ctx_0.calling_context);
        let is_context_1_root = ExecutionContext.is_empty(ctx_1.calling_context);
        assert is_context_0_root = is_context_1_root;
        if (is_context_0_root != FALSE) {
            return ();
        }

        assert_call_context_equal(ctx_0.call_context, ctx_1.call_context);
        assert ctx_0.program_counter = ctx_1.program_counter;
        assert ctx_0.stopped = ctx_1.stopped;

        assert_array_equal(
            ctx_0.return_data_len, ctx_0.return_data, ctx_1.return_data_len, ctx_1.return_data
        );

        // TODO: Implement assert_dict_access_equal and finalize this helper once Stack and Memory are stabilized
        // assert ctx_0.stack = ctx_1.stack;
        // assert ctx_0.memory = ctx_1.memory;

        assert ctx_0.gas_limit = ctx_1.gas_limit;
        assert ctx_0.gas_price = ctx_1.gas_price;
        assert ctx_0.starknet_contract_address = ctx_1.starknet_contract_address;
        assert ctx_0.address.evm = ctx_1.address.evm;
        return assert_execution_context_equal(ctx_0.calling_context, ctx_1.calling_context);
    }

    func print_uint256(val: Uint256) {
        %{
            low = memory[ids.val.address_]
            high = memory[ids.val.address_ + 1]
            print(f"Uint256(low={low}, high={high}) = {2 ** 128 * high + low}")
        %}
        return ();
    }

    func print_array(arr_len: felt, arr: felt*) {
        %{
            print(f"{ids.arr_len=}")
            for i in range(ids.arr_len):
                print(f"arr[{i}]={memory[ids.arr + i]}")
        %}
        return ();
    }

    func print_call_context(call_context: model.CallContext*) {
        %{ print("print_call_context") %}
        %{ print(f"{ids.call_context.value=}") %}
        %{ print("calldata") %}
        print_array(call_context.calldata_len, call_context.calldata);
        %{ print("bytecode") %}
        print_array(call_context.bytecode_len, call_context.bytecode);
        return ();
    }

    func print_execution_context(execution_context: model.ExecutionContext*) {
        %{ print("print_execution_context") %}
        print_call_context(execution_context.call_context);
        %{
            print(f"{ids.execution_context.program_counter=}")
            print(f"{ids.execution_context.stopped=}")
        %}
        %{ print("return_data") %}
        print_array(execution_context.return_data_len, execution_context.return_data);
        // TODO: See note above for stack and memory
        // stack
        // memory
        %{
            print(f"{ids.execution_context.gas_used=}")
            print(f"{ids.execution_context.gas_limit=}")
            print(f"{ids.execution_context.gas_price}")
            print(f"{ids.execution_context.starknet_contract_address=}")
            print(f"{ids.execution_context.address.evm=}")
        %}
        return ();
    }
}
