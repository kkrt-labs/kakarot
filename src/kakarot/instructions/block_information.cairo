// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math_cmp import is_in_range
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.bool import FALSE
from starkware.cairo.common.dict import DictAccess, dict_read

// Internal dependencies
from kakarot.model import model
from utils.utils import Helpers
from kakarot.execution_context import ExecutionContext
from kakarot.stack import Stack
from kakarot.constants import Constants, native_token_address
from kakarot.interfaces.interfaces import IEth

// @title BlockInformation information opcodes.
// @notice This file contains the functions to execute for block information opcodes.
// @author @abdelhamidbakhta
// @custom:namespace BlockInformation
namespace BlockInformation {
    // Define constants.
    const GAS_COST_BLOCKHASH = 20;
    const GAS_COST_COINBASE = 2;
    const GAS_COST_TIMESTAMP = 2;
    const GAS_COST_NUMBER = 2;
    const GAS_COST_DIFFICULTY = 2;
    const GAS_COST_GASLIMIT = 2;
    const GAS_COST_CHAINID = 2;
    const GAS_COST_SELFBALANCE = 5;
    const GAS_COST_BASEFEE = 2;

    // @notice COINBASE operation.
    // @dev Get the hash of one of the 256 most recent complete blocks.
    // @dev 0 if the block number is not in the valid range.
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 20
    // @custom:stack_consumed_elements 1
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_blockhash{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Get the blockNumber
        let (stack: model.Stack*, block_number: Uint256) = Stack.pop(ctx.stack);

        // Check if blockNumber is within bounds by checking with current block number
        // Valid range is the last 256 blocks (not including the current one)
        let (local current_block_number: felt) = get_block_number();
        let in_range = is_in_range(block_number.low, current_block_number - 256, current_block_number);

        // If not in range, return 0
        if (in_range == FALSE) {
            let blockhash: Uint256 =  Helpers.to_uint256(val=0);
        } else {
            // Get blockhash from corresponding block number and push to stack
            let block_context: DictAccess* = ctx.block_context;
            let (_blockhash: felt) = dict_read{dict_ptr=block_context}(key=block_number.low);
            let blockhash: Uint256 =  Helpers.to_uint256(val=_blockhash);
        }
        let stack: model.Stack* = Stack.push(self=stack, element=blockhash);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_BLOCKHASH);
        return ctx;
    }

    // @notice COINBASE operation.
    // @dev Get the block's beneficiary address.
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_coinbase{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the coinbase address.
        // TODO: switch to real coinbase addr when going to prod
        let coinbase_address = Helpers.to_uint256(val=Constants.MOCK_COINBASE_ADDRESS);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=coinbase_address);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_COINBASE);
        return ctx;
    }

    // @notice TIMESTAMP operation.
    // @dev Get the block’s timestamp
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_timestamp{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the block’s timestamp
        let (current_timestamp) = get_block_timestamp();
        let block_timestamp = Helpers.to_uint256(val=current_timestamp);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=block_timestamp);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_TIMESTAMP);
        return ctx;
    }

    // @notice NUMBER operation.
    // @dev Get the block number
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_number{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get the block number.
        let (current_block) = get_block_number();
        let block_number = Helpers.to_uint256(val=current_block);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=block_number);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_NUMBER);
        return ctx;
    }

    // @notice DIFFICULTY operation.
    // @dev Get Difficulty
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_difficulty{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the Difficulty.
        let difficulty = Helpers.to_uint256(val=0);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=difficulty);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_DIFFICULTY);
        return ctx;
    }

    // @notice GASLIMIT operation.
    // @dev Get gas limit
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_gaslimit{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the Gas Limit
        let gas_limit = Helpers.to_uint256(val=ctx.gas_limit);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=gas_limit);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_GASLIMIT);
        return ctx;
    }

    // @notice CHAINID operation.
    // @dev Get the chain ID.
    // @custom:since Instanbul
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_chainid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the chain ID.
        let chain_id = Helpers.to_uint256(val=Constants.CHAIN_ID);
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=chain_id);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_CHAINID);
        return ctx;
    }

    // @notice SELFBALANCE operation.
    // @dev Get balance of currently executing contract
    // @custom:since Istanbul
    // @custom:group Block Information
    // @custom:gas 5
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_selfbalance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;
        // Get balance of current executing contract address balance and push to stack.
        let (native_token_address_) = native_token_address.read();
        let (balance: Uint256) = IEth.balanceOf(
            contract_address=native_token_address_, account=ctx.starknet_contract_address
        );
        let stack: model.Stack* = Stack.push(self=ctx.stack, element=balance);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_SELFBALANCE);
        return ctx;
    }

    // @notice BASEFEE operation.
    // @dev Get base fee
    // @custom:since Frontier
    // @custom:group Block Information
    // @custom:gas 2
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 1
    // @param ctx The pointer to the execution context
    // @return The pointer to the updated execution context.
    func exec_basefee{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        // Get the base fee.
        let basefee = Helpers.to_uint256(val=0);

        let stack: model.Stack* = Stack.push(self=ctx.stack, element=basefee);

        // Update the execution context.
        // Update context stack.
        let ctx = ExecutionContext.update_stack(self=ctx, new_stack=stack);
        // Increment gas used.
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=GAS_COST_BASEFEE);
        return ctx;
    }
}
