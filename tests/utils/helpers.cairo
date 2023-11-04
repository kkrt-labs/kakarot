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
from starkware.cairo.common.dict_access import DictAccess

// Internal dependencies
from kakarot.constants import Constants
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.utils import Helpers

namespace TestHelpers {
    func init_context_at_address(
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
        tempvar origin = new model.Address(0, 0);
        local call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=bytecode_len,
            calldata=calldata,
            calldata_len=1,
            value=0,
            gas_limit=Constants.TRANSACTION_GAS_LIMIT,
            gas_price=0,
            origin=origin,
            calling_context=root_context,
            address=address,
            read_only=FALSE,
            is_create=FALSE,
        );
        let ctx: model.ExecutionContext* = ExecutionContext.init(call_context);
        return ctx;
    }

    func init_context(bytecode_len: felt, bytecode: felt*) -> model.ExecutionContext* {
        return init_context_at_address(bytecode_len, bytecode, 0, 0);
    }

    func init_stack_with_values{range_check_ptr}(stack_len: felt, stack: Uint256*) -> model.Stack* {
        let stack_ = Stack.init();

        tempvar range_check_ptr = range_check_ptr;
        tempvar stack_ = stack_;
        tempvar stack_len = stack_len;
        tempvar stack = stack;

        jmp cond;

        loop:
        let range_check_ptr = [ap - 4];
        let stack_ = cast([ap - 3], model.Stack*);
        let stack_len = [ap - 2];
        let stack = cast([ap - 1], Uint256*);

        let stack_ = Stack.push(stack_, stack + (stack_len - 1) * Uint256.SIZE);

        let range_check_ptr = [ap - 2];
        tempvar stack_len = stack_len - 1;
        tempvar stack = stack;

        static_assert range_check_ptr == [ap - 4];
        static_assert stack_ == [ap - 3];
        static_assert stack_len == [ap - 2];
        static_assert stack == [ap - 1];

        cond:
        let stack_len = [ap - 2];
        jmp loop if stack_len != 0;

        let range_check_ptr = [ap - 4];
        let stack_ = cast([ap - 3], model.Stack*);

        return stack_;
    }

    func init_context_with_stack(
        bytecode_len: felt, bytecode: felt*, stack: model.Stack*
    ) -> model.ExecutionContext* {
        let ctx: model.ExecutionContext* = init_context(bytecode_len, bytecode);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func init_context_at_address_with_stack(
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

    func init_context_with_return_data(
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

    func assert_array_equal(array_0_len: felt, array_0: felt*, array_1_len: felt, array_1: felt*) {
        assert array_0_len = array_1_len;
        if (array_0_len == 0) {
            return ();
        }
        assert [array_0] = [array_1];
        return assert_array_equal(array_0_len - 1, array_0 + 1, array_1_len - 1, array_1 + 1);
    }

    func assert_call_context_equal(ctx_0: model.CallContext*, ctx_1: model.CallContext*) {
        assert ctx_0.value = ctx_1.value;
        assert_array_equal(ctx_0.bytecode_len, ctx_0.bytecode, ctx_1.bytecode_len, ctx_1.bytecode);
        assert_array_equal(ctx_0.calldata_len, ctx_0.calldata, ctx_1.calldata_len, ctx_1.calldata);

        assert ctx_0.gas_limit = ctx_1.gas_limit;
        assert ctx_0.address.starknet = ctx_1.address.starknet;
        assert ctx_0.gas_price = ctx_1.gas_price;
        assert ctx_0.address.evm = ctx_1.address.evm;
        assert_execution_context_equal(ctx_0.calling_context, ctx_1.calling_context);
        return ();
    }

    func assert_execution_context_equal(
        ctx_0: model.ExecutionContext*, ctx_1: model.ExecutionContext*
    ) {
        let is_context_0_root = ExecutionContext.is_empty(ctx_0.call_context.calling_context);
        let is_context_1_root = ExecutionContext.is_empty(ctx_1.call_context.calling_context);
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
        return ();
    }

    func print_uint256(val: Uint256) {
        %{
            low = ids.val.low
            high = ids.val.high
            print(f"Uint256(low={low}, high={high}) = {2 ** 128 * high + low}")
        %}
        return ();
    }

    func print_array(name: felt, arr_len: felt, arr: felt*) {
        %{
            print(bytes.fromhex(f"{ids.name:062x}").decode().replace('\x00',''))
            arr = [memory[ids.arr + i] for i in range(ids.arr_len)]
            print(arr)
        %}
        return ();
    }

    func print_dict(name: felt, dict_ptr: DictAccess*, pointer_size: felt) {
        %{
            print(bytes.fromhex(f"{ids.name:062x}").decode().replace('\x00',''))
            data = __dict_manager.get_dict(ids.dict_ptr)
            print(
                {k: v if isinstance(v, int) else [memory[v + i] for i in range(ids.pointer_size)] for k, v in data.items()}
            )
        %}
        return ();
    }

    func print_call_context(call_context: model.CallContext*) {
        %{ print("print_call_context") %}
        print_array('calldata', call_context.calldata_len, call_context.calldata);
        print_array('bytecode', call_context.bytecode_len, call_context.bytecode);
        %{
            print(f"{ids.call_context.gas_limit=}")
            print(f"{ids.call_context.gas_price=}")
            print(f"{ids.call_context.origin.evm=:040x}")
            print(f"{ids.call_context.origin.starknet=:064x}")
            print(f"{ids.call_context.address.evm=:040x}")
            print(f"{ids.call_context.address.starknet=:064x}")
            print(f"{ids.call_context.read_only=}")
            print(f"{ids.call_context.is_create=}")
        %}
        return ();
    }

    func print_execution_context(execution_context: model.ExecutionContext*) {
        %{ print("print_execution_context") %}

        print_call_context(execution_context.call_context);
        print_dict('stack', execution_context.stack.dict_ptr, Uint256.SIZE);

        print_array(
            'return_data', execution_context.return_data_len, execution_context.return_data
        );
        %{
            print(f"{ids.execution_context.program_counter=}")
            print(f"{ids.execution_context.stopped=}")
            print(f"{ids.execution_context.gas_used=}")
            print(f"{ids.execution_context.reverted=}")
        %}
        return ();
    }
}
