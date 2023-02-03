// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import keccak_bigend, finalize_keccak
from starkware.starknet.common.syscalls import get_caller_address, get_tx_info
from starkware.cairo.common.uint256 import Uint256

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.memory import Memory
from kakarot.constants import native_token_address
from kakarot.interfaces.interfaces import IEth, IAccount
from kakarot.accounts.library import Accounts

// @title Environmental information opcodes.
// @notice This file contains the functions to execute for environmental information opcodes.
// @author @abdelhamidbakhta
// @custom:namespace EnvironmentalInformation
namespace EnvironmentalInformation {
    // Define constants.
    const GAS_COST_ADDRESS = 2;
    const GAS_COST_BALANCE = 100;
    const GAS_COST_ORIGIN = 2;
    const GAS_COST_CALLER = 2;
    const GAS_COST_CALLVALUE = 2;
    const GAS_COST_CALLDATALOAD = 3;
    const GAS_COST_CALLDATASIZE = 2;
    const GAS_COST_CALLDATACOPY = 3;
    const GAS_COST_CODESIZE = 2;
    const GAS_COST_CODECOPY = 3;
    const GAS_COST_GASPRICE = 2;
    const GAS_COST_EXTCODESIZE = 2600;
    const GAS_COST_EXTCODECOPY = 2600;
    const GAS_COST_RETURNDATASIZE = 2;
    const GAS_COST_RETURNDATACOPY = 3;
    const GAS_COST_EXTCODEHASH = 2600;

    // @notice ADDRESS operation.
    // @dev Get address of currently executing account.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the current execution contract from the context,
        // convert to Uin256, and push to Stack.
        let address = Helpers.to_uint256(ctx.evm_contract_address);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=address);
        // Update the execution context.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_ADDRESS);
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
    // @return The pointer to the updated execution context.
    func exec_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the evm address.
        let (stack: model.Stack*, address: Uint256) = Stack.pop(ctx.stack);

        let felt_address = Helpers.uint256_to_felt(address);
        // Get the starknet account address from the evm account address
        let (starknet_contract_address) = Accounts.compute_starknet_address(felt_address);
        // Get the number of native tokens owned by the given starknet account
        let (native_token_address_) = native_token_address.read();
        let (balance: Uint256) = IEth.balanceOf(
            contract_address=native_token_address_, account=starknet_contract_address
        );

        let stack: model.Stack* = Stack.push(stack, balance);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_BALANCE);
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
    // @return The pointer to the updated execution context.
    func exec_origin{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the transaction info which contains the starknet origin address
        let (tx_info) = get_tx_info();
        // Get the EVM address from Starknet address
        let (evm_contract_address) = IAccount.get_evm_address(tx_info.account_contract_address);
        let origin_address = Helpers.to_uint256(evm_contract_address);

        // Update Context stack
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=origin_address);
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_ORIGIN);
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
    // @return The pointer to the updated execution context.
    func exec_caller{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Get caller address.
        let (current_address) = get_caller_address();
        let (current_evm_address) = IAccount.get_evm_address(current_address);
        let is_root = ExecutionContext.is_root(ctx);
        let evm_address = (1 - is_root) * ctx.calling_context.evm_contract_address + is_root * current_evm_address;
        let evm_address_uint256 = Helpers.to_uint256(evm_address);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=evm_address_uint256);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_CALLER);
        return ctx;
    }

    // @notice CALLVALUE operation.
    // @dev Get deposited value by the instruction/transaction responsible for this execution.
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_callvalue{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let uint256_value: Uint256 = Helpers.to_uint256(ctx.call_context.value);
        let stack: model.Stack* = Stack.push(ctx.stack, uint256_value);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLVALUE);
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
    // @return The pointer to the updated execution context.
    func exec_calldataload{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;

        // Stack input:
        // 0 - offset: calldata offset of the word we read (32 byte steps).
        let (stack, calldata_offset) = Stack.pop(stack);

        let (sliced_calldata: felt*) = alloc();

        let calldata: felt* = ctx.call_context.calldata;
        let calldata_len: felt = ctx.call_context.calldata_len;

        // read calldata at offset
        let sliced_calldata: felt* = Helpers.slice_data(
            data_len=calldata_len, data=calldata, data_offset=calldata_offset.low, slice_len=32
        );
        let uint256_sliced_calldata: Uint256 = Helpers.bytes32_to_uint256(sliced_calldata);

        // Push CallData word onto stack
        let stack: model.Stack* = Stack.push(self=stack, element=uint256_sliced_calldata);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_CALLDATALOAD);
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
    // @return The pointer to the updated execution context.
    func exec_calldatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let calldata_size = Helpers.to_uint256(ctx.call_context.calldata_len);
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
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=element_len.low, element=sliced_calldata, offset=offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_CALLDATACOPY);
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
    // @return The pointer to the updated execution context.
    func exec_codesize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the bytecode size.
        let code_size = Helpers.to_uint256(ctx.call_context.bytecode_len);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=code_size);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_CODESIZE);
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
    // @return The pointer to the updated execution context.
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

    // @notice GASPRICE operation
    // @dev Get price of gas in current environment
    // @custom:since Frontier
    // @custom:group Environmental Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_gasprice{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the gasprice.
        let cost_felt = ExecutionContext.compute_intrinsic_gas_cost(ctx);
        let cost_uint256 = Helpers.to_uint256(cost_felt);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=cost_uint256);

        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_GASPRICE);

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
    // @return The pointer to the updated execution context.
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
        let address_felt = Helpers.uint256_to_felt(address_uint256);

        // Get the starknet address from the given evm address
        let (starknet_contract_address) = Accounts.compute_starknet_address(address_felt);

        local bytecode_len;
        // TODO (https://github.com/sayajin-labs/kakarot/issues/474)
        //      should be able to check that there is a deployed starknet contract at this address
        // if not return bytecode_len 0
        let (bytecode_len) = IAccount.bytecode_len(contract_address=starknet_contract_address);

        // bytecode_len cannot be greater than 24k in the EVM
        let stack = Stack.push(stack, Uint256(low=bytecode_len, high=0));

        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);

        // TODO:distinction between warm and cold addresses determines dynamic cost
        //  for now we assume a cold address, which sets dynamic cost to 2600
        // see: https://www.evm.codes/about#accesssets
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_EXTCODESIZE);

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
    // @return The pointer to the updated execution context.
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
        let address_uint256 = popped[0];
        let dest_offset = popped[1];
        let offset = popped[2];
        let size = popped[3];

        let address_felt = Helpers.uint256_to_felt(address_uint256);

        // Get the starknet address from the given evm address

        let (starknet_contract_address) = Accounts.compute_starknet_address(address_felt);

        // TODO (https://github.com/sayajin-labs/kakarot/issues/474)
        //      should be able to check that there is a deployed starknet contract at this address
        // we get the bytecode from the Starknet_contract
        let (bytecode_len, bytecode) = IAccount.bytecode(
            contract_address=starknet_contract_address
        );

        // Get bytecode slice from offset to size
        // in the case were
        // evm address returns no bytecode or has no `starknet_contract_address`
        // the bytecode len would be zero and the byte array empty,
        // which `Helpers.slice_data` would return an array
        // with the requested `size` of zeroes

        let sliced_bytecode: felt* = Helpers.slice_data(
            data_len=bytecode_len, data=bytecode, data_offset=offset.low, slice_len=size.low
        );

        // Write bytecode slice to memory at dest_offset
        let (memory, memory_expansion_cost) = Memory.ensure_length(
            self=ctx.memory, length=dest_offset.low + size.low
        );
        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory, element_len=size.low, element=sliced_bytecode, offset=dest_offset.low
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let (minimum_word_size) = Helpers.minimum_word_count(size.low);

        // TODO:distinction between warm and cold addresses determines `address_access_cost`
        // for now we assume a cold address, which sets `address_access_cost` to 2600
        // see: https://www.evm.codes/about#accesssets

        let ctx = ExecutionContext.increment_gas_used(
            self=ctx, inc_value=3 * minimum_word_size + memory_expansion_cost + GAS_COST_EXTCODECOPY
        );

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
    // @return The pointer to the updated execution context.
    func exec_returndatasize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get return data size.
        let return_data_size = Helpers.to_uint256(ctx.sub_context.return_data_len);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=return_data_size);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_RETURNDATASIZE);
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
    // @return Updated execution context.
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

        let return_data_len: felt = ctx.sub_context.return_data_len;
        let return_data: felt* = ctx.sub_context.return_data;

        let sliced_return_data: felt* = Helpers.slice_data(
            data_len=return_data_len,
            data=return_data,
            data_offset=return_data_offset.low,
            slice_len=element_len.low,
        );

        let memory: model.Memory* = Memory.store_n(
            self=ctx.memory,
            element_len=element_len.low,
            element=sliced_return_data,
            offset=offset.low,
        );

        // Update context memory.
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CALLDATACOPY);
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
    // @return The pointer to the updated execution context
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
        let (stack, address_uint256) = Stack.pop(self=stack);
        let address_felt = Helpers.uint256_to_felt(address_uint256);

        // Get the starknet address from the given evm address
        let (starknet_contract_address) = Accounts.compute_starknet_address(address_felt);

        // TODO (https://github.com/sayajin-labs/kakarot/issues/474)
        //      should be able to check that there is a deployed starknet contract at this address
        let (bytecode_len, bytecode) = IAccount.bytecode(
            contract_address=starknet_contract_address
        );

        let (local dest: felt*) = alloc();
        // convert to little endian
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=bytecode_len,
            bytes=bytecode,
            index=0,
            size=bytecode_len,
            bytes8=0,
            bytes8_shift=0,
            dest=dest,
            dest_index=0,
        );

        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        with keccak_ptr {
            let (result) = keccak_bigend(inputs=dest, n_bytes=bytecode_len);

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let stack: model.Stack* = Stack.push(self=stack, element=result);
        // Update context stack
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used (COLD ACCESS)
        // see: https://www.evm.codes/about#accesssets
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_EXTCODEHASH);
        return ctx;
    }
}
