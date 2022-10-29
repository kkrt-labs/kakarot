// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_lt
from starkware.cairo.common.math_cmp import is_le_felt
from starkware.cairo.common.memcpy import memcpy

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.constants import native_token_address, registry_address
from kakarot.interfaces.interfaces import IEth, IRegistry

// @title Environmental information opcodes.
// @notice This file contains the functions to execute for environmental information opcodes.
// @author @abdelhamidbakhta
// @custom:namespace EnvironmentalInformation
namespace EnvironmentalInformation {
    // Define constants.
    const GAS_COST_CODESIZE = 2;
    const GAS_COST_CALLER = 2;
    const GAS_COST_RETURNDATASIZE = 2;
    const GAS_COST_CALLDATALOAD = 3;
    const GAS_COST_CALLDATASIZE = 2;
    const GAS_COST_ORIGIN = 2;
    const GAS_COST_BALANCE = 100;
    const GAS_COST_CALLDATACOPY = 3;
    const GAS_COST_CODECOPY = 3;
    const GAS_COST_RETURNDATACOPY = 3;

    // @notice BALANCE opcode.
    // @dev Get ETH balance of the specified address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 100 || 2600
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x31 - BALANCE")
        %}

        // Get the address.
        let (stack: model.Stack*, address: Uint256) = Stack.pop(ctx.stack);

        let addr: felt = Helpers.uint256_to_felt(address);
        let (registry_address_) = registry_address.read();
        let (starknet_address) = IRegistry.get_starknet_address(
            contract_address=registry_address_, evm_address=address.low
        );
        let (native_token_address_) = native_token_address.read();
        let (balance: Uint256) = IEth.balanceOf(
            contract_address=native_token_address_, account=starknet_address
        );

        let stack: model.Stack* = Stack.push(stack, balance);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_BALANCE);
        return ctx;
    }
    // @notice CODESIZE operation.
    // @dev Get size of code running in current environment.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_codesize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x38 - CODESIZE")
        %}

        // Get the code size.
        let code_size = Helpers.to_uint256(ctx.code_len);
        let stack: model.Stack* = Stack.push(ctx.stack, code_size);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CODESIZE);
        return ctx;
    }

    // @notice ORIGIN operation.
    // @dev Get execution origination address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_origin{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x32 - ORIGIN")
        %}

        // Get  EVM address from Starknet address

        let (tx_info) = get_tx_info();
        let (registry_address_) = registry_address.read();
        let (evm_address) = IRegistry.get_evm_address(
            registry_address_, tx_info.account_contract_address
        );
        let origin_address = Helpers.to_uint256(evm_address);

        // Update Context stack
        let stack: model.Stack* = Stack.push(ctx.stack, origin_address);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_ORIGIN);
        return ctx;
    }

    // @notice CALLER operation.
    // @dev Get caller address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_caller{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x33 - CALLER")
        %}
        // Get caller address.
        let (current_address) = get_caller_address();
        let caller_address = Helpers.to_uint256(current_address);
        let stack: model.Stack* = Stack.push(ctx.stack, caller_address);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLER);
        return ctx;
    }

    // @notice RETURNDATASIZE operation.
    // @dev Get the size of return data.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_returndatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x3d - RETURNDATASIZE")
        %}
        // Get return data size.
        let return_data_size = Helpers.to_uint256(ctx.return_data_len);
        let stack: model.Stack* = Stack.push(ctx.stack, return_data_size);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_RETURNDATASIZE);
        return ctx;
    }

    // @notice CALLDATALOAD operation.
    // @dev Push a word from the calldata onto the stack.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_calldataload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{ print("0x35 - CALLDATALOAD") %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: calldata offset of the word we read (32 byte steps).
        let (stack, calldata_offset) = Stack.pop(stack);

        let (sliced_calldata: felt*) = alloc();

        let calldata: felt* = ctx.calldata;
        let calldata_len: felt = ctx.calldata_len;

        // read calldata at offset
        let sliced_calldata: felt* = Helpers.slice_data(
            data_len=calldata_len, data=calldata, data_offset=calldata_offset.low, slice_len=32
        );
        let uint256_sliced_calldata: Uint256 = Helpers.bytes_to_uint256(sliced_calldata);

        // Push CallData word onto stack

        let stack: model.Stack* = Stack.push(stack, uint256_sliced_calldata);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLDATALOAD);
        return ctx;
    }

    // @notice CALLDATASIZE operation.
    // @dev Get the size of return data.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_calldatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{
            import logging
            logging.info("0x36 - CALLDATASIZE")
        %}
        let calldata_size = Helpers.to_uint256(ctx.calldata_len);
        let stack: model.Stack* = Stack.push(ctx.stack, calldata_size);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLDATASIZE);
        return ctx;
    }

    // @notice CALLDATACOPY operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_calldatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x37 - CALLDATACOPY")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - calldata_offset: offset for calldata from where data will be copied.
        // 2 - element_len: bytes length of the copied calldata.

        let (stack, offset) = Stack.pop(stack);
        let (stack, calldata_offset) = Stack.pop(stack);
        let (stack, element_len) = Stack.pop(stack);

        let calldata: felt* = ctx.calldata;
        let calldata_len: felt = ctx.calldata_len;

        let sliced_calldata: felt* = Helpers.slice_data(
            data_len=calldata_len,
            data=calldata,
            data_offset=calldata_offset.low,
            slice_len=element_len.low,
        );

        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_calldata, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLDATACOPY);
        return ctx;
    }

    // @notice CODECOPY operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_codecopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x39 - CODECOPY")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - code_offset: offset for code from where data will be copied.
        // 2 - element_len: bytes length of the copied code.

        let (stack, offset) = Stack.pop(stack);
        let (stack, code_offset) = Stack.pop(stack);
        let (stack, element_len) = Stack.pop(stack);

        let code: felt* = ctx.code;
        let code_len: felt = ctx.code_len;

        let sliced_code: felt* = Helpers.slice_data(
            data_len=code_len, data=code, data_offset=code_offset.low, slice_len=element_len.low
        );

        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_code, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CODECOPY);
        return ctx;
    }

    // @notice RETURNDATACOPY operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return Updated execution context.
    func exec_returndatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        %{
            import logging
            logging.info("0x3e - RETURNDATACOPY")
        %}

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - code_offset: offset for code from where data will be copied.
        // 2 - element_len: bytes length of the copied code.

        let (stack, offset) = Stack.pop(stack);
        let (stack, return_data_offset) = Stack.pop(stack);
        let (stack, element_len) = Stack.pop(stack);

        let return_data: felt* = ctx.return_data;
        let return_data_len: felt = ctx.return_data_len;

        let sliced_return_data: felt* = Helpers.slice_data(
            data_len=return_data_len, data=return_data, data_offset=return_data_offset.low, slice_len=element_len.low
        );

        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_return_data, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(ctx, memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_RETURNDATACOPY);
        return ctx;
    }
}
