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
from utils.utils import Helpers
from kakarot.constants import Constants
from utils.uint256 import uint256_to_uint160
from utils.array import slice
from utils.bytes import bytes_to_bytes8_little_endian

// @title Environmental information opcodes.
// @notice This file contains the functions to execute for environmental information opcodes.
namespace EnvironmentalInformation {
    func exec_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let address = Helpers.to_uint256(ctx.call_context.address.evm);
        let stack = Stack.push(ctx.stack, address);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

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
        let address = Helpers.to_uint256(caller);
        let stack = Stack.push(ctx.stack, address);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func exec_callvalue{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let value = Helpers.to_uint256(ctx.call_context.value);
        let stack = Stack.push(ctx.stack, value);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }

    func exec_calldataload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, offset) = Stack.pop(ctx.stack);

        let (sliced_calldata: felt*) = alloc();
        slice(
            sliced_calldata,
            ctx.call_context.calldata_len,
            ctx.call_context.calldata,
            offset.low,
            32,
        );
        let calldata = Helpers.bytes32_to_uint256(sliced_calldata);
        let stack = Stack.push_uint256(stack, calldata);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        return ctx;
    }

    func exec_calldatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let stack = Stack.push_uint128(ctx.stack, ctx.call_context.calldata_len);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func exec_calldatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 3);
        let dest_offset = popped[0];
        let offset = popped[1];
        let size = popped[2];

        let ctx = ExecutionContext.update_stack(ctx, stack);

        let (sliced_calldata: felt*) = alloc();
        slice(
            sliced_calldata,
            ctx.call_context.calldata_len,
            ctx.call_context.calldata,
            offset.low,
            size.low,
        );

        // Write caldata slice to memory at dest_offset
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, dest_offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory = Memory.store_n(ctx.memory, size.low, sliced_calldata, dest_offset.low);
        let ctx = ExecutionContext.update_memory(ctx, memory);

        return ctx;
    }

    func exec_codesize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let stack = Stack.push_uint128(ctx.stack, ctx.call_context.bytecode_len);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func exec_codecopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 3);
        let dest_offset = popped[0];
        let offset = popped[1];
        let size = popped[2];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let (local sliced_code: felt*) = alloc();
        slice(
            sliced_code,
            ctx.call_context.bytecode_len,
            ctx.call_context.bytecode,
            offset.low,
            size.low,
        );

        // Write bytecode slice to memory at dest_offset
        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, dest_offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory = Memory.store_n(ctx.memory, size.low, sliced_code, dest_offset.low);

        let ctx = ExecutionContext.update_memory(ctx, memory);
        return ctx;
    }

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

    func exec_extcodesize{
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

        // bytecode_len cannot be greater than 24k in the EVM
        let stack = Stack.push_uint128(stack, account.code_len);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }

    func exec_extcodecopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 4);
        let dest_offset = popped[1];
        let offset = popped[2];
        let size = popped[3];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let evm_address = uint256_to_uint160(popped[0]);
        let (starknet_address) = Account.compute_starknet_address(evm_address);
        tempvar address = new model.Address(starknet_address, evm_address);
        let (state, account) = State.get_account(ctx.state, address);

        let (sliced_bytecode: felt*) = alloc();
        slice(sliced_bytecode, account.code_len, account.code, offset.low, size.low);

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

    func exec_returndatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let stack = Stack.push_uint128(ctx.stack, ctx.return_data_len);
        let ctx = ExecutionContext.update_stack(ctx, stack);
        return ctx;
    }

    func exec_returndatacopy{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let (stack, popped) = Stack.pop_n(ctx.stack, 3);
        let dest_offset = popped[0];
        let offset = popped[1];
        let size = popped[2];
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let sliced_return_data: felt* = alloc();
        slice(sliced_return_data, ctx.return_data_len, ctx.return_data, offset.low, size.low);

        let memory_expansion_cost = Memory.expansion_cost(ctx.memory, dest_offset.low + size.low);
        let ctx = ExecutionContext.charge_gas(ctx, memory_expansion_cost);
        if (ctx.reverted != FALSE) {
            return ctx;
        }
        let memory = Memory.store_n(ctx.memory, size.low, sliced_return_data, dest_offset.low);
        let ctx = ExecutionContext.update_memory(ctx, memory);
        return ctx;
    }

    func exec_extcodehash{
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

        let (local dst: felt*) = alloc();
        bytes_to_bytes8_little_endian(dst, account.code_len, account.code);

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = cairo_keccak_bigend(dst, account.code_len);
        }

        finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);

        tempvar hash = new Uint256(result.low, result.high);
        let stack = Stack.push(stack, hash);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.update_state(ctx, state);

        return ctx;
    }
}
