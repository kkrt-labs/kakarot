// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math_cmp import is_le

// Internal dependencies
from kakarot.account import Account
from kakarot.errors import Errors
from kakarot.execution_context import ExecutionContext
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from kakarot.state import State
from kakarot.constants import Constants
from utils.utils import Helpers
from utils.uint256 import uint256_to_uint160

// @title Environmental information opcodes.
// @notice This file contains the functions to execute for environmental information opcodes.
namespace EnvironmentalInformation {
    // @notice ADDRESS operation.
    // @dev Get address of currently executing account.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the current execution contract from the context,
        // convert to Uint256, and push to Stack.
        let address = Helpers.to_uint256(ctx.call_context.address.evm);
        let stack = Stack.push(ctx.stack, address);
        // Update the execution context.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice BALANCE opcode.
    // @dev Get ETH balance of the specified address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 100 || 2600
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, address_uint256) = Stack.pop(ctx.stack);

        let evm_address = uint256_to_uint160([address_uint256]);
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);
        let (state, account) = State.get_account(ctx.state, address);
        let stack = Stack.push_uint256(stack, [account.balance]);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);
        return ctx;
    }

    // @notice ORIGIN operation.
    // @dev Get execution origination address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_origin{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let origin_address = Helpers.to_uint256(ctx.call_context.origin.evm);

        let stack = Stack.push(self=ctx.stack, element=origin_address);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CALLER operation.
    // @dev Get caller address.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_caller{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let calling_context = ctx.call_context.calling_context;
        let is_root = ExecutionContext.is_empty(calling_context);
        if (is_root == 0) {
            tempvar caller = calling_context.call_context.address.evm;
        } else {
            tempvar caller = ctx.call_context.origin.evm;
        }
        let evm_address_uint256 = Helpers.to_uint256(caller);
        let stack = Stack.push(ctx.stack, evm_address_uint256);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CALLVALUE operation.
    // @dev Get deposited value by the instruction/transaction responsible for this execution.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_callvalue{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let uint256_value = Helpers.to_uint256(ctx.call_context.value);
        let stack = Stack.push(ctx.stack, uint256_value);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CALLDATALOAD operation.
    // @dev Push a word from the calldata onto the stack.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_calldataload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, calldata_offset) = Stack.pop(ctx.stack);

        if (calldata_offset.high != 0) {
            let ctx = ExecutionContext.update_stack(ctx, stack);
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let (sliced_calldata: felt*) = alloc();

        let calldata: felt* = ctx.call_context.calldata;
        let calldata_len: felt = ctx.call_context.calldata_len;

        // read calldata at offset
        let sliced_calldata: felt* = Helpers.slice_data(
            data_len=calldata_len, data=calldata, data_offset=calldata_offset.low, slice_len=32
        );
        let uint256_sliced_calldata = Helpers.bytes32_to_uint256(sliced_calldata);

        // Push CallData word onto stack
        let stack = Stack.push_uint256(stack, uint256_sliced_calldata);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CALLDATASIZE operation.
    // @dev Get the size of return data.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_calldatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let stack = Stack.push_uint128(ctx.stack, ctx.call_context.calldata_len);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CALLDATACOPY operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return Updated execution context.
    func exec_calldatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - calldata_offset: offset for calldata from where data will be copied.
        // 2 - element_len: bytes length of the copied calldata.
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        let offset = popped[0];
        let calldata_offset = popped[1];
        let element_len = popped[2];

        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + calldata_offset.high + element_len.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let calldata: felt* = ctx.call_context.calldata;
        let calldata_len: felt = ctx.call_context.calldata_len;

        // Get calldata slice from calldata_offset to element_len
        let sliced_calldata: felt* = Helpers.slice_data(
            data_len=calldata_len,
            data=calldata,
            data_offset=calldata_offset.low,
            slice_len=element_len.low,
        );

        // Write caldata slice to memory at offset
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + element_len.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_calldata, offset=offset.low
        );
        let ctx = ExecutionContext.update_memory(ctx, memory);

        return ctx;
    }

    // @notice CODESIZE operation.
    // @dev Get size of bytecode running in current environment.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_codesize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the bytecode size.
        let code_size = Helpers.to_uint256(ctx.call_context.bytecode_len);

        let stack = Stack.push_uint128(ctx.stack, ctx.call_context.bytecode_len);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice CODECOPY (0x39) operation.
    // @dev Copies slice of bytecode to memory
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_codecopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - code_offset: offset for bytecode from where data will be copied.
        // 2 - element_len: bytes length of the copied bytecode.
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        let offset = popped[0];
        let code_offset = popped[1];
        let element_len = popped[2];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + code_offset.high + element_len.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        // Get bytecode slice from code_offset to element_len
        let bytecode: felt* = ctx.call_context.bytecode;
        let bytecode_len: felt = ctx.call_context.bytecode_len;
        let sliced_code: felt* = Helpers.slice_data(
            data_len=bytecode_len,
            data=bytecode,
            data_offset=code_offset.low,
            slice_len=element_len.low,
        );

        // Write bytecode slice to memory at offset
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + element_len.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_code, offset=offset.low
        );

        let ctx = ExecutionContext.update_memory(ctx, memory);
        return ctx;
    }

    // @notice GASPRICE operation
    // @dev Get price of gas in current environment
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_gasprice{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // TODO: since gas_price is a felt, it might panic when being cast to a Uint256.low,
        // Add check gas_price < 2 ** 128
        // `split_felt` might be too expensive for this if we know gas_price < 2 ** 128
        let stack = Stack.push_uint128(ctx.stack, ctx.call_context.gas_price);

        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }

    // @notice EXTCODESIZE operation
    // @dev Get size of an account’s code
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 100 || 2600
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_extcodesize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - address: 20-byte address of the contract to query.
        let (stack, address_uint256) = Stack.pop(self=stack);
        let evm_address = uint256_to_uint160([address_uint256]);
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);
        let (state, account) = State.get_account(ctx.state, address);

        // bytecode_len cannot be greater than 24k in the EVM
        let stack = Stack.push_uint128(stack, account.code_len);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }

    // @notice EXTCODECOPY operation
    // @dev Copy an account's code to memory
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 100 || 2600
    // @custom:stack_consumed_elements 4
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_extcodecopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - address: 20-byte address of the contract to query.
        // 1 - dest_offset: byte offset in the memory where the result will be copied.
        // 2 - offset: byte offset in the code to copy.
        // 3 - size: byte size to copy.
        let (stack, popped) = Stack.pop_n(self=stack, n=4);
        let dest_offset = popped[1];
        let offset = popped[2];
        let size = popped[3];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (dest_offset.high + offset.high + size.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let evm_address = uint256_to_uint160(popped[0]);
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);
        let (state, account) = State.get_account(ctx.state, address);

        // Get bytecode slice from offset to size
        // in the case were
        // evm address returns no bytecode or has no `starknet_contract_address`
        // the bytecode len would be zero and the byte array empty,
        // which `Helpers.slice_data` would return an array
        // with the requested `size` of zeroes
        let sliced_bytecode: felt* = Helpers.slice_data(
            data_len=account.code_len, data=account.code, data_offset=offset.low, slice_len=size.low
        );

        // Write bytecode slice to memory at dest_offset
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, dest_offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory = Memory.store_n(ctx.memory, size.low, sliced_bytecode, dest_offset.low);

        let ctx = ExecutionContext.update_memory(ctx, memory);
        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }

    // @notice RETURNDATASIZE operation.
    // @dev Get the size of return data.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_returndatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get return data size.
        let stack = Stack.push_uint128(ctx.stack, ctx.return_data_len);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    // @notice RETURNDATACOPY operation
    // @dev Save word to memory.
    // @custom:since Frontier
    // @custom:group Stack Memory Storage and Flow operations.
    // @custom:gas 3
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext Updated execution context.
    func exec_returndatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: memory offset of the work we save.
        // 1 - code_offset: offset for bytecode from where data will be copied.
        // 2 - element_len: bytes length of the copied bytecode.
        let (stack, popped) = Stack.pop_n(self=stack, n=3);
        let offset = popped[0];
        let return_data_offset = popped[1];
        let element_len = popped[2];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        if (offset.high + return_data_offset.high + element_len.high != 0) {
            let ctx = ExecutionContext.charge_gas(ctx, ctx.call_context.gas_limit);
            return ctx;
        }

        let sliced_return_data: felt* = Helpers.slice_data(
            data_len=ctx.return_data_len,
            data=ctx.return_data,
            data_offset=return_data_offset.low,
            slice_len=element_len.low,
        );

        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, offset.low + element_len.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory,
            element_len=element_len.low,
            element=sliced_return_data,
            offset=offset.low,
        );
        let ctx = ExecutionContext.update_memory(ctx, memory);
        return ctx;
    }

    // @notice EXTCODEHASH operation
    // @dev Get hash of a contract's code
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 100 || 2600
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context
    func exec_extcodehash{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - address: 20-byte address of the contract to query.
        let (stack, address_uint256) = Stack.pop(stack);
        let evm_address = uint256_to_uint160([address_uint256]);
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);

        let (state, account) = State.get_account(ctx.state, address);
        let has_code_or_nonce = Account.has_code_or_nonce(account);
        let (state, account) = State.get_account(state, address);
        let account_exists = has_code_or_nonce + account.balance.low;
        // Relevant cases:
        // https://github.com/ethereum/go-ethereum/blob/master/core/vm/instructions.go#L392
        if (account_exists == 0) {
            let stack = Stack.push_uint128(stack, 0);
            let ctx = ExecutionContext.update_stack(ctx, stack);
            let ctx = ExecutionContext.update_state(ctx, state);
            return ctx;
        }

        let (local dest: felt*) = alloc();
        // convert to little endian
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=account.code_len,
            bytes=account.code,
            index=0,
            size=account.code_len,
            bytes8=0,
            bytes8_shift=0,
            dest=dest,
            dest_index=0,
        );

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(inputs=dest, n_bytes=account.code_len);
        }

        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

        tempvar hash = new Uint256(result.low, result.high);
        let stack = Stack.push(stack, hash);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }
}
