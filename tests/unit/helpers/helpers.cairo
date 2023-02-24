// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_add,
    uint256_eq,
    assert_uint256_eq,
)
from starkware.cairo.common.math import split_felt

// Internal dependencies
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.model import model
from utils.utils import Helpers

namespace TestHelpers {
    func init_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
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
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(bytecode_len: felt, bytecode: felt*, stack: model.Stack*) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context(bytecode_len, bytecode);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func init_context_at_address_with_stack_and_caller_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        address: felt,
        bytecode_len: felt,
        bytecode: felt*,
        stack: model.Stack*,
        starknet_address: felt,
    ) -> model.ExecutionContext* {
        alloc_locals;

        let self: model.ExecutionContext* = init_context_with_stack(bytecode_len, bytecode, stack);

        return new model.ExecutionContext(
            call_context=self.call_context,
            program_counter=self.program_counter,
            stopped=self.stopped,
            return_data=self.return_data,
            return_data_len=self.return_data_len,
            stack=self.stack,
            memory=self.memory,
            gas_used=self.gas_used,
            gas_limit=self.gas_limit,
            gas_price=self.gas_price,
            starknet_contract_address=starknet_address,
            evm_contract_address=address,
            calling_context=self.calling_context,
            sub_context=self.sub_context,
            destroy_contracts_len=self.destroy_contracts_len,
            destroy_contracts=self.destroy_contracts,
            read_only=self.read_only,
            );
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

        return TestHelpers.init_context(bytecode_count, bytecode);
    }

    func init_context_with_stack_and_sub_ctx{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        bytecode_len: felt, bytecode: felt*, stack: model.Stack*, sub_ctx: model.ExecutionContext*
    ) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context_with_stack(bytecode_len, bytecode, stack);
        let ctx = ExecutionContext.update_sub_context(ctx, sub_ctx);
        return ctx;
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
        let ctx = ExecutionContext.update_return_data(ctx, return_data_len, return_data);
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
        execution_context_0: model.ExecutionContext*, execution_context_1: model.ExecutionContext*
    ) {
        let is_context_0_root = ExecutionContext.is_root(execution_context_0);
        let is_context_1_root = ExecutionContext.is_root(execution_context_1);
        assert is_context_0_root = is_context_1_root;
        if (is_context_0_root != FALSE) {
            return ();
        }

        assert_call_context_equal(
            execution_context_0.call_context, execution_context_1.call_context
        );
        assert execution_context_0.program_counter = execution_context_1.program_counter;
        assert execution_context_0.stopped = execution_context_1.stopped;

        assert_array_equal(
            execution_context_0.return_data_len,
            execution_context_0.return_data,
            execution_context_1.return_data_len,
            execution_context_1.return_data,
        );

        // TODO: Implement assert_dict_access_equal and finalize this helper once Stack and Memory are stabilized
        // assert execution_context_0.stack = execution_context_1.stack;
        // assert execution_context_0.memory = execution_context_1.memory;

        assert execution_context_0.gas_limit = execution_context_1.gas_limit;
        assert execution_context_0.gas_price = execution_context_1.gas_price;
        assert execution_context_0.starknet_contract_address = execution_context_1.starknet_contract_address;
        assert execution_context_0.evm_contract_address = execution_context_1.evm_contract_address;
        return assert_execution_context_equal(
            execution_context_0.calling_context, execution_context_1.calling_context
        );
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
            print(f"{ids.execution_context.evm_contract_address=}")
        %}
        return ();
    }
}
