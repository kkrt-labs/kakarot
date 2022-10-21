// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin

from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.math import split_felt

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.constants import Constants

// @title BlockInformation information opcodes.
// @notice This file contains the functions to execute for block information opcodes.
// @author @abdelhamidbakhta
// @custom:namespace BlockInformation
namespace BlockInformation {
    // Define constants.
    const GAS_COST_CHAINID = 2;
    const GAS_COST_COINBASE = 2;
    const GAS_COST_TIMESTAMP = 2;
    const GAS_COST_NUMBER = 2;

    // @notice CHAINID operation.
    // @dev Get the chain ID.
    // @custom:since Instanbul
    // @custom:group Block Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_chainid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{ print("0x46 - CHAINID") %}
        // Get the chain ID.
        let chain_id = Helpers.to_uint256(Constants.CHAIN_ID);
        let stack: model.Stack* = Stack.push(ctx.stack, chain_id);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_CHAINID);
        return ctx;
    }

    // @notice COINBASE operation.
    // @dev Get the block's beneficiary address.
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 3
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_coinbase{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{ print("0x41 - COINBASE") %}
        // Get the coinbase address.
        let coinbase_address = Helpers.to_uint256(Constants.COINBASE_ADDRESS);
        let stack: model.Stack* = Stack.push(ctx.stack, coinbase_address);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_COINBASE);
        return ctx;
    }

    // @notice TIMESTAMP operation.
    // @dev Get the block’s timestamp
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_timestamp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{ print("0x42 - TIMESTAMP") %}
        // Get the block’s timestamp
        let (current_timestamp) = get_block_timestamp();
        let (high, low) = split_felt(current_timestamp);
        let block_timestamp = Uint256(low, high);

        let stack: model.Stack* = Stack.push(ctx.stack, block_timestamp);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_TIMESTAMP);
        return ctx;
    }

    // @notice NUMBER operation.
    // @dev Get the block number
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @return The pointer to the updated execution context.
    func exec_number{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        %{ print("0x43 - NUMBER") %}
        // Get the block number.
        let (current_block) = get_block_number();
        let (high, low) = split_felt(current_block);
        let block_number = Uint256(low, high);

        let stack: model.Stack* = Stack.push(ctx.stack, block_number);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(ctx, stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(ctx, GAS_COST_NUMBER);
        return ctx;
    }
}
