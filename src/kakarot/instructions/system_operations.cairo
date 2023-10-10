// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.cairo_keccak.keccak import cairo_keccak_bigend, finalize_keccak
from starkware.cairo.common.dict import (
    DictAccess,
    dict_new,
    dict_read,
    dict_squash,
    dict_update,
    dict_write,
)
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.math import split_felt
from starkware.cairo.common.math_cmp import is_le, is_not_zero, is_nn
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (
    deploy as deploy_syscall,
    get_contract_address,
    get_tx_info,
)

// Internal dependencies
from kakarot.constants import contract_account_class_hash, native_token_address, Constants
from kakarot.precompiles.precompiles import Precompiles
from kakarot.execution_context import ExecutionContext
from kakarot.interfaces.interfaces import IContractAccount, IERC20, IAccount
from kakarot.memory import Memory
from kakarot.model import model
from kakarot.stack import Stack
from utils.rlp import RLP
from utils.utils import Helpers
from kakarot.accounts.library import Accounts

// @title System operations opcodes.
// @notice This file contains the functions to execute for system operations opcodes.
namespace SystemOperations {
    // Gas cost generated from using a CALL opcode (CALL, STATICCALL, etc.) with positive value parameter
    const GAS_COST_POSITIVE_VALUE = 9000;
    // Gas cost generated from accessing a "cold" address in the network: https://www.evm.codes/about#accesssets
    const GAS_COST_COLD_ADDRESS_ACCESS = 2600;
    const GAS_COST_CREATE = 32000;
    // @notice CREATE operation.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 3
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_create{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // This instruction is disallowed when called from a `staticcall` context, which we demark by a read_only attribute
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only = FALSE;
        }

        // Stack input:
        // 0 - value: value in wei to send to the new account
        // 1 - offset: byte offset in the memory in bytes (initialization code)
        // 2 - size: byte size to copy (size of initialization code)
        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=3);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let size = popped[2];

        // create dynamic gas:
        // dynamic_gas = 6 * minimum_word_size + memory_expansion_cost + deployment_code_execution_cost + code_deposit_cost
        // -> ``memory_expansion_cost + deployment_code_execution_cost + code_deposit_cost`` is handled inside ``initialize_sub_context``
        let (minimum_word_size) = Helpers.minimum_word_count(size.low);
        let word_size_gas = 6 * minimum_word_size;
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=word_size_gas);

        let sub_ctx = CreateHelper.initialize_sub_context(ctx=ctx, popped_len=3, popped=popped);

        return sub_ctx;
    }

    // @notice CREATE2 operation.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 4
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_create2{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // This instruction is disallowed when called from a `staticcall` context, which we demark by a read_only attribute
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only = FALSE;
        }

        // Stack input:
        // 0 - value: value in wei to send to the new account
        // 1 - offset: byte offset in the memory in bytes (initialization code)
        // 2 - size: byte size to copy (size of initialization code)
        // 3 - salt: salt for address generation
        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=4);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let sub_ctx = CreateHelper.initialize_sub_context(ctx=ctx, popped_len=4, popped=popped);

        return sub_ctx;
    }

    // @notice INVALID operation.
    // @dev Designated invalid instruction.
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 0
    // @custom:stack_produced_elements 0
    // @param ctx The pointer to the execution context
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_invalid{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        with_attr error_message("Kakarot: 0xFE: Invalid Opcode") {
            assert TRUE = FALSE;
        }
        // TODO: map the concept of consuming all the gas given to the context

        return ctx;
    }

    // @notice RETURN operation.
    // @dev Halt execution returning output data
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas NaN
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_return{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let stack = ctx.stack;
        let (stack, offset) = Stack.pop(stack);
        let (stack, size) = Stack.pop(stack);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let (local return_data: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=size.low, element=return_data, offset=offset.low
        );
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        let ctx = ExecutionContext.increment_gas_used(ctx, gas_cost);
        let ctx = ExecutionContext.update_return_data(
            ctx, return_data_len=size.low, return_data=return_data
        );
        let ctx = ExecutionContext.stop(ctx);

        return ctx;
    }

    // @notice REVERT operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 2
    // @custom:stack_produced_elements 0
    // @return ExecutionContext The pointer to the updated execution context.
    func exec_revert{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Get stack and memory from context
        let stack = ctx.stack;
        let memory = ctx.memory;

        // Stack input:
        // 0 - offset: byte offset in the memory in bytes
        // 1 - size: byte size to copy
        let (stack, popped) = Stack.pop_n(self=stack, n=2);

        let offset = popped[0];
        let size = popped[1];

        // Load revert reason from offset
        let (revert_reason: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(memory, size.low, revert_reason, offset.low);

        let ctx = ExecutionContext.update_stack(ctx, stack);
        let ctx = ExecutionContext.revert(self=ctx, revert_reason=revert_reason, size=size.low);
        let ctx = ExecutionContext.update_memory(self=ctx, new_memory=memory);
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=gas_cost);
        return ctx;
    }

    // @notice CALL operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_call{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            calling_ctx=ctx, with_value=TRUE, read_only=ctx.read_only
        );
        // This instruction is disallowed when called from a `staticcall` context when there is an attempt to transfer funds, which occurs when there is a nonzero value argument.
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only * sub_ctx.call_context.value = FALSE;
        }

        if (sub_ctx.call_context.value == 0) {
            return sub_ctx;
        }

        let (native_token_address_) = native_token_address.read();
        let amount_u256 = Helpers.to_uint256(sub_ctx.call_context.value);
        let sender = ctx.starknet_contract_address;
        let recipient = sub_ctx.starknet_contract_address;
        let (success) = IERC20.transferFrom(
            contract_address=native_token_address_,
            sender=sender,
            recipient=recipient,
            amount=amount_u256,
        );
        with_attr error_message(
                "Kakarot: 0xF1: failed to transfer token from {sender} to {recipient}") {
            assert success = TRUE;
        }

        return sub_ctx;
    }

    // @notice STATICCALL operation.
    // @dev
    // @custom:since Homestead
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_staticcall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            calling_ctx=ctx, with_value=FALSE, read_only=TRUE
        );
        return sub_ctx;
    }

    // @notice CALLCODE operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 7
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_callcode{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            calling_ctx=ctx, with_value=TRUE, read_only=ctx.read_only
        );
        let recipient = sub_ctx.starknet_contract_address;
        let sub_ctx = ExecutionContext.update_addresses(
            sub_ctx, ctx.starknet_contract_address, ctx.evm_contract_address
        );

        if (sub_ctx.call_context.value == 0) {
            return sub_ctx;
        }

        let (native_token_address_) = native_token_address.read();
        let amount_u256 = Helpers.to_uint256(sub_ctx.call_context.value);
        let sender = ctx.starknet_contract_address;
        let (success) = IERC20.transferFrom(
            contract_address=native_token_address_,
            sender=sender,
            recipient=recipient,
            amount=amount_u256,
        );
        with_attr error_message(
                "Kakarot: 0xF2: failed to transfer token from {sender} to {recipient}") {
            assert success = TRUE;
        }

        return sub_ctx;
    }

    // @notice DELEGATECALL operation.
    // @dev
    // @custom:since Byzantium
    // @custom:group System Operations
    // @custom:gas 0 + dynamic gas
    // @custom:stack_consumed_elements 6
    // @custom:stack_produced_elements 1
    // @return ExecutionContext The pointer to the sub context.
    func exec_delegatecall{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        let sub_ctx = CallHelper.init_sub_context(
            calling_ctx=ctx, with_value=FALSE, read_only=ctx.read_only
        );
        let sub_ctx = ExecutionContext.update_addresses(
            sub_ctx, ctx.starknet_contract_address, ctx.evm_contract_address
        );

        return sub_ctx;
    }

    // @notice SELFDESTRUCT operation.
    // @dev
    // @custom:since Frontier
    // @custom:group System Operations
    // @custom:gas 3000 + dynamic gas
    // @custom:stack_consumed_elements 1
    // @return ExecutionContext The pointer to the updated execution_context.
    func exec_selfdestruct{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // This instruction is disallowed when called from a `staticcall` context, which we demark by a read_only attribute
        with_attr error_message("Kakarot: StateModificationError") {
            assert ctx.read_only = FALSE;
        }

        // Get stack and memory from context
        let stack = ctx.stack;

        // Stack input:
        // 0 - address: account to send the current balance to
        let (stack, address_uint256) = Stack.pop(stack);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let address_felt = Helpers.uint256_to_felt(address_uint256);

        // Get the number of native tokens owned by the given starknet
        // account and transfer them to receiver
        let (native_token_address_) = native_token_address.read();
        let (balance: Uint256) = IERC20.balanceOf(
            contract_address=native_token_address_, account=ctx.starknet_contract_address
        );
        let sender = ctx.starknet_contract_address;
        let (success) = IERC20.transferFrom(
            contract_address=native_token_address_,
            sender=sender,
            recipient=address_felt,
            amount=balance,
        );
        with_attr error_message(
                "Kakarot: 0xFF: failed to transfer token from {sender} to {address_felt}") {
            assert success = TRUE;
        }

        // Save contract to be destroyed at the end of the transaction
        let ctx = ExecutionContext.push_to_destroy_contract(
            self=ctx, destroy_contract=ctx.starknet_contract_address
        );

        return ctx;
    }
}

namespace CallHelper {
    // @notice Helper for the CALLs ops family as they all do the same data preprocessing.

    struct CallArgs {
        gas: felt,
        address: felt,
        value: felt,
        args_size: felt,
        calldata: felt*,
    }

    // @dev: with_value arg lets specify if the call requires a value (CALL, CALLCODE) or not (STATICCALL, DELEGATECALL).
    // @return ExecutionContext The pointer to the context and call args.
    func prepare_args{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, with_value: felt) -> (
        ctx: model.ExecutionContext*, call_args: CallArgs
    ) {
        alloc_locals;
        let (stack, popped) = Stack.pop_n(self=ctx.stack, n=6 + with_value);
        let ctx = ExecutionContext.update_stack(ctx, stack);

        let gas = 2 ** 128 * popped[0].high + popped[0].low;
        let address = 2 ** 128 * popped[1].high + popped[1].low;
        let stack_value = (2 ** 128 * popped[2].high + popped[2].low) * with_value;
        // if the call op expects value to be on the stack, we return it, else the value is the calling call context value
        let value = with_value * stack_value + (1 - with_value) * ctx.call_context.value;
        let args_offset = 2 ** 128 * popped[2 + with_value].high + popped[2 + with_value].low;
        let args_size = 2 ** 128 * popped[3 + with_value].high + popped[3 + with_value].low;
        let ret_offset = 2 ** 128 * popped[4 + with_value].high + popped[4 + with_value].low;
        let ret_size = 2 ** 128 * popped[5 + with_value].high + popped[5 + with_value].low;

        // Note: We use the calling context's `return_data` & `return_data_len` to store
        // the location and size of the sub context's return data to be stored at teardown
        let return_data: felt* = alloc();
        assert [return_data] = ret_offset;
        let ctx = ExecutionContext.update_return_data(ctx, ret_size, return_data);

        // Load calldata from Memory
        let (calldata: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=args_size, element=calldata, offset=args_offset
        );

        // TODO: account for value_to_empty_account_cost in dynamic gas
        let value_nn = is_nn(value);
        let value_not_zero = is_not_zero(value);
        let value_is_positive = value_nn * value_not_zero;
        let dynamic_gas = gas_cost + SystemOperations.GAS_COST_COLD_ADDRESS_ACCESS +
            SystemOperations.GAS_COST_POSITIVE_VALUE * value_is_positive;
        let ctx = ExecutionContext.increment_gas_used(self=ctx, inc_value=dynamic_gas);

        let remaining_gas = ctx.gas_limit - ctx.gas_used;
        let (max_allowed_gas, _) = Helpers.div_rem(remaining_gas, 64);
        let gas_limit = Helpers.min(gas, max_allowed_gas);

        let call_args = CallArgs(
            gas=gas_limit, address=address, value=value, args_size=args_size, calldata=calldata
        );

        let ctx = ExecutionContext.update_memory(ctx, memory);

        return (ctx, call_args);
    }

    // @notice The shared logic of the CALL ops, allowing CALL, CALLCODE, STATICCALL, and DELEGATECALL to share structure and parameterize whether the call requires a value (CALL, CALLCODE) and whether the returned sub context's is read only (STATICCODE)
    // @param calling_ctx The pointer to the calling execution context.
    // @param with_value The boolean that determines whether the sub-context's calling context has a value read from the calling context's stack or the calling context's calling context.
    // @param read_only The boolean that determines whether state modifications can be executed from the sub-execution context.
    // @return ExecutionContext The pointer to the sub context.
    func init_sub_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(
        calling_ctx: model.ExecutionContext*, with_value: felt, read_only: felt
    ) -> model.ExecutionContext* {
        alloc_locals;
        let (calling_ctx, local call_args) = CallHelper.prepare_args(
            ctx=calling_ctx, with_value=with_value
        );

        // Check if the called address is a precompiled contract
        let is_precompile = Precompiles.is_precompile(address=call_args.address);
        if (is_precompile == FALSE) {
            let (local return_data: felt*) = alloc();
            let (bytecode_len, bytecode) = Accounts.get_bytecode(call_args.address);
            tempvar call_context = new model.CallContext(
                bytecode=bytecode,
                bytecode_len=bytecode_len,
                calldata=call_args.calldata,
                calldata_len=call_args.args_size,
                value=call_args.value,
            );
            let (starknet_contract_address) = Accounts.compute_starknet_address(call_args.address);
            let sub_ctx = ExecutionContext.init(
                call_context=call_context,
                starknet_contract_address=starknet_contract_address,
                evm_contract_address=call_args.address,
                origin=calling_ctx.origin,
                gas_limit=call_args.gas,
                gas_price=calling_ctx.gas_price,
                calling_context=calling_ctx,
                return_data_len=0,
                return_data=return_data,
                read_only=read_only,
            );

            return sub_ctx;
        }

        let sub_ctx = Precompiles.run(
            address=call_args.address,
            calldata_len=call_args.args_size,
            calldata=call_args.calldata,
            value=call_args.value,
            calling_context=calling_ctx,
        );

        return sub_ctx;
    }

    // @notice At the end of a sub-context call, the calling context's stack and memory are updated.
    // @return ExecutionContext The pointer to the updated calling context.
    func finalize_calling_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        // Put status in stack
        let is_reverted = ExecutionContext.is_reverted(self=ctx);
        let status = Uint256(low=1 - is_reverted, high=0);
        let stack = Stack.push(ctx.calling_context.stack, status);

        // Store RETURN_DATA in memory
        // Call args ret_offset and ret_size temporarily stored in calling context return_data fields
        // See prepare_args
        let ret_offset = [ctx.calling_context.return_data];
        let ret_size = ctx.calling_context.return_data_len;
        let return_data = Helpers.slice_data(
            data_len=ctx.return_data_len, data=ctx.return_data, data_offset=0, slice_len=ret_size
        );
        let memory = Memory.store_n(ctx.calling_context.memory, ret_size, return_data, ret_offset);

        // Update SELFDESTROY contracts
        Helpers.fill_array(
            fill_len=ctx.destroy_contracts_len,
            input_arr=ctx.destroy_contracts,
            output_arr=ctx.calling_context.destroy_contracts +
            ctx.calling_context.destroy_contracts_len,
        );

        // Return the updated calling context
        return new model.ExecutionContext(
            call_context=ctx.calling_context.call_context,
            program_counter=ctx.calling_context.program_counter,
            stopped=ctx.calling_context.stopped,
            return_data=ctx.return_data,
            return_data_len=ctx.return_data_len,
            stack=stack,
            memory=memory,
            gas_used=ctx.calling_context.gas_used + ctx.gas_used,
            gas_limit=ctx.calling_context.gas_limit,
            gas_price=ctx.calling_context.gas_price,
            starknet_contract_address=ctx.calling_context.starknet_contract_address,
            evm_contract_address=ctx.calling_context.evm_contract_address,
            origin=ctx.calling_context.origin,
            calling_context=ctx.calling_context.calling_context,
            destroy_contracts_len=ctx.calling_context.destroy_contracts_len +
            ctx.destroy_contracts_len,
            destroy_contracts=ctx.calling_context.destroy_contracts,
            events_len=ctx.calling_context.events_len,
            events=ctx.calling_context.events,
            create_addresses_len=ctx.calling_context.create_addresses_len,
            create_addresses=ctx.calling_context.create_addresses,
            revert_contract_state=ctx.calling_context.revert_contract_state,
            reverted=ctx.calling_context.reverted,
            read_only=ctx.calling_context.read_only,
        );
    }
}

namespace CreateHelper {
    // @notice Constructs an evm contract address for the create opcode
    //         via last twenty bytes of the keccak hash of:
    //         keccak256(rlp([sender_address,sender_nonce])).
    //         See [CREATE](https://www.evm.codes/#f0).
    // @param sender_address The evm sender address.
    // @param bytecode_len The length of the initialization code.
    // @param nonce The nonce given to the create opcode.
    // @return ExecutionContext The pointer to the updated calling context.
    func get_create_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(sender_address: felt, nonce: felt) -> (evm_contract_address: felt) {
        alloc_locals;
        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        let (local address_packed_bytes: felt*) = alloc();

        // pack sender address, padded twenty bytes
        // the address should be twenty bytes, so we skip the leading 12 elements
        let (sender_address_high, sender_address_low) = split_felt(sender_address);

        let (address_packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
            value=Uint256(low=sender_address_low, high=sender_address_high),
            byte_array_offset=12,
            byte_array_len=Constants.ADDRESS_BYTES_LEN,
            dest_offset=0,
            dest_len=0,
            dest=address_packed_bytes,
        );

        // encode address rlp
        let (local packed_bytes: felt*) = alloc();
        let (packed_bytes_len) = RLP.encode_byte_array(
            address_packed_bytes_len, address_packed_bytes, 0, packed_bytes
        );

        // encode nonce rlp
        let (packed_bytes_len) = RLP.encode_felt(nonce, packed_bytes_len, packed_bytes);

        let (local rlp_list: felt*) = alloc();
        let (rlp_list_len: felt) = RLP.encode_list(packed_bytes_len, packed_bytes, rlp_list);

        let (local packed_bytes8: felt*) = alloc();
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=rlp_list_len,
            bytes=rlp_list,
            index=0,
            size=rlp_list_len,
            bytes8=0,
            bytes8_shift=0,
            dest=packed_bytes8,
            dest_index=0,
        );

        with keccak_ptr {
            let (create_hash) = cairo_keccak_bigend(inputs=packed_bytes8, n_bytes=rlp_list_len);

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let create_address = Helpers.keccak_hash_to_evm_contract_address(create_hash);
        return (create_address,);
    }

    // @notice Constructs an evm contract address for the create2 opcode
    //         via last twenty bytes of the keccak hash of:
    //         keccak256(0xff + sender_address + salt +
    //         keccak256(initialization_code))[12:].
    //         See [CREATE2](https://www.evm.codes/#f5).
    // @param sender_address The evm sender address.
    // @param bytecode_len The length of the initialization code.
    // @param bytecode The offset to store the element at.
    // @param salt The salt given to the create2 opcode.
    // @return ExecutionContext The pointer to the updated calling context.
    func get_create2_address{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(sender_address: felt, bytecode_len: felt, bytecode: felt*, salt: Uint256) -> (
        evm_contract_address: felt
    ) {
        alloc_locals;
        let (keccak_ptr: felt*) = alloc();
        local keccak_ptr_start: felt* = keccak_ptr;

        let (local bytecode_bytes8: felt*) = alloc();
        Helpers.bytes_to_bytes8_little_endian(
            bytes_len=bytecode_len,
            bytes=bytecode,
            index=0,
            size=bytecode_len,
            bytes8=0,
            bytes8_shift=0,
            dest=bytecode_bytes8,
            dest_index=0,
        );
        with keccak_ptr {
            // get keccak hash of bytecode
            let (bytecode_hash_bigend) = cairo_keccak_bigend(
                inputs=bytecode_bytes8, n_bytes=bytecode_len
            );
            // get keccak hash of
            // marker + caller_address + salt + bytecode_hash
            let (local packed_bytes: felt*) = alloc();

            // 0xff is by convention the marker involved in deterministic address creation for create2
            let (packed_bytes_len) = Helpers.felt_to_bytes(0xff, 0, packed_bytes);

            // pack sender address, padded twenty bytes
            // the address should be twenty bytes, so we skip the leading 12 elements
            let (sender_address_high, sender_address_low) = split_felt(sender_address);
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=Uint256(low=sender_address_low, high=sender_address_high),
                byte_array_offset=12,
                byte_array_len=Constants.ADDRESS_BYTES_LEN,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            // pack salt, padded 32 bytes
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=salt,
                byte_array_offset=0,
                byte_array_len=32,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            // pack bytecode keccak hash, padded 32 bytes
            let (packed_bytes_len) = Helpers.uint256_to_dest_bytes_array(
                value=bytecode_hash_bigend,
                byte_array_offset=0,
                byte_array_len=32,
                dest_offset=packed_bytes_len,
                dest_len=packed_bytes_len,
                dest=packed_bytes,
            );

            let (local packed_bytes8: felt*) = alloc();
            Helpers.bytes_to_bytes8_little_endian(
                bytes_len=packed_bytes_len,
                bytes=packed_bytes,
                index=0,
                size=packed_bytes_len,
                bytes8=0,
                bytes8_shift=0,
                dest=packed_bytes8,
                dest_index=0,
            );

            let (create2_hash) = cairo_keccak_bigend(
                inputs=packed_bytes8, n_bytes=packed_bytes_len
            );

            finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
        }

        let create2_address = Helpers.keccak_hash_to_evm_contract_address(create2_hash);
        return (create2_address,);
    }

    // @notice Deploy a new Contract account and initialize a sub context at these addresses
    //         with bytecode from calling context memory.
    // @param ctx The pointer to the calling context.
    // @param popped_len The length of popped.
    // @param popped The memory.
    // @return ExecutionContext The pointer to the updated calling context.
    func initialize_sub_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*, popped_len: felt, popped: Uint256*) -> model.ExecutionContext* {
        alloc_locals;

        // Load bytecode code from memory
        let value = popped[0];
        let offset = popped[1];
        let size: Uint256 = popped[2];

        let (bytecode: felt*) = alloc();
        let (memory, gas_cost) = Memory.load_n(
            self=ctx.memory, element_len=size.low, element=bytecode, offset=offset.low
        );
        let ctx = ExecutionContext.update_memory(ctx, memory);

        let ctx = ExecutionContext.increment_gas_used(
            self=ctx, inc_value=gas_cost + SystemOperations.GAS_COST_CREATE
        );

        // Prepare execution context
        let (empty_array: felt*) = alloc();
        tempvar call_context: model.CallContext* = new model.CallContext(
            bytecode=bytecode,
            bytecode_len=size.low,
            calldata=empty_array,
            calldata_len=0,
            value=value.low,
        );
        let (local return_data: felt*) = alloc();
        let (empty_destroy_contracts: felt*) = alloc();
        let (empty_create_addresses: felt*) = alloc();
        let (empty_events: model.Event*) = alloc();
        let stack = Stack.init();
        let memory = Memory.init();
        let empty_context = ExecutionContext.init_empty();

        // create2 context pops 4 off the stack, create pops 3
        // so we use popped_len to derive the way we should handle
        // the creation of evm addresses
        if (popped_len != 4) {
            let (nonce) = IContractAccount.get_nonce(ctx.starknet_contract_address);

            let (evm_contract_address) = CreateHelper.get_create_address(
                ctx.evm_contract_address, nonce
            );

            let (contract_account_class_hash_) = contract_account_class_hash.read();
            IContractAccount.increment_nonce(ctx.starknet_contract_address);
            let (starknet_contract_address) = Accounts.create(
                contract_account_class_hash_, evm_contract_address
            );
            let ctx = ExecutionContext.push_create_address(ctx, starknet_contract_address);
            let (local revert_contract_state_dict_start) = default_dict_new(0);
            tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
                revert_contract_state_dict_start, revert_contract_state_dict_start);
            tempvar sub_ctx = new model.ExecutionContext(
                call_context=call_context,
                program_counter=0,
                stopped=FALSE,
                return_data=return_data,
                return_data_len=0,
                stack=stack,
                memory=memory,
                gas_used=0,
                gas_limit=0,
                gas_price=0,
                starknet_contract_address=starknet_contract_address,
                evm_contract_address=evm_contract_address,
                origin=ctx.origin,
                calling_context=ctx,
                destroy_contracts_len=0,
                destroy_contracts=empty_destroy_contracts,
                events_len=0,
                events=empty_events,
                create_addresses_len=0,
                create_addresses=empty_create_addresses,
                revert_contract_state=revert_contract_state,
                reverted=FALSE,
                read_only=FALSE,
            );

            return sub_ctx;
        } else {
            let _nonce = popped[3];
            let (evm_contract_address) = CreateHelper.get_create2_address(
                sender_address=ctx.evm_contract_address,
                bytecode_len=size.low,
                bytecode=bytecode,
                salt=_nonce,
            );

            let (contract_account_class_hash_) = contract_account_class_hash.read();
            IContractAccount.increment_nonce(ctx.starknet_contract_address);
            let (starknet_contract_address) = Accounts.create(
                contract_account_class_hash_, evm_contract_address
            );
            let ctx = ExecutionContext.push_create_address(ctx, starknet_contract_address);
            let (local revert_contract_state_dict_start) = default_dict_new(0);
            tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
                revert_contract_state_dict_start, revert_contract_state_dict_start);
            tempvar sub_ctx = new model.ExecutionContext(
                call_context=call_context,
                program_counter=0,
                stopped=FALSE,
                return_data=return_data,
                return_data_len=0,
                stack=stack,
                memory=memory,
                gas_used=0,
                gas_limit=0,
                gas_price=0,
                starknet_contract_address=starknet_contract_address,
                evm_contract_address=evm_contract_address,
                origin=ctx.origin,
                calling_context=ctx,
                destroy_contracts_len=0,
                destroy_contracts=empty_destroy_contracts,
                events_len=0,
                events=empty_events,
                create_addresses_len=0,
                create_addresses=empty_create_addresses,
                revert_contract_state=revert_contract_state,
                reverted=FALSE,
                read_only=FALSE,
            );

            return sub_ctx;
        }
    }

    // @notice At the end of a sub-context initiated with CREATE or CREATE2, the calling context's stack is updated.
    // @param ctx The pointer to the calling context.
    // @return ExecutionContext The pointer to the updated calling context.
    func finalize_calling_context{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let is_reverted = ExecutionContext.is_reverted(ctx);
        // code_deposit_code := 200 * deployed_code_size * BYTES_PER_FELT (as Kakarot packs bytes inside a felt)
        // dynamic_gas :=  deployment_code_execution_cost + code_deposit_cost
        // In the case of a reverted create context, the gas of the reverted context should be rolled back and not consumed
        let gas = (ctx.gas_used + 200 * ctx.return_data_len * Constants.BYTES_PER_FELT) * (
            1 - is_reverted
        );

        // Stack output: the address of the deployed contract, 0 if the deployment failed.
        let (address_high, address_low) = split_felt(ctx.evm_contract_address * (1 - is_reverted));
        let stack = Stack.push(
            ctx.calling_context.stack, Uint256(low=address_low, high=address_high)
        );

        // Update SELFDESTROY contracts
        Helpers.fill_array(
            fill_len=ctx.destroy_contracts_len,
            input_arr=ctx.destroy_contracts,
            output_arr=ctx.calling_context.destroy_contracts +
            ctx.calling_context.destroy_contracts_len,
        );

        // Return the updated calling context
        tempvar calling_context = new model.ExecutionContext(
            call_context=ctx.calling_context.call_context,
            program_counter=ctx.calling_context.program_counter,
            stopped=ctx.calling_context.stopped,
            return_data=ctx.return_data,
            return_data_len=ctx.return_data_len,
            stack=stack,
            memory=ctx.calling_context.memory,
            gas_used=ctx.calling_context.gas_used + gas,
            gas_limit=ctx.calling_context.gas_limit,
            gas_price=ctx.calling_context.gas_price,
            starknet_contract_address=ctx.calling_context.starknet_contract_address,
            evm_contract_address=ctx.calling_context.evm_contract_address,
            origin=ctx.calling_context.origin,
            calling_context=ctx.calling_context.calling_context,
            destroy_contracts_len=ctx.calling_context.destroy_contracts_len +
            ctx.destroy_contracts_len,
            destroy_contracts=ctx.calling_context.destroy_contracts,
            events_len=ctx.calling_context.events_len,
            events=ctx.calling_context.events,
            create_addresses_len=ctx.calling_context.create_addresses_len,
            create_addresses=ctx.calling_context.create_addresses,
            revert_contract_state=ctx.calling_context.revert_contract_state,
            reverted=ctx.calling_context.reverted,
            read_only=ctx.calling_context.read_only,
        );

        if (is_reverted != 0) {
            return calling_context;
        } else {
            IContractAccount.write_bytecode(
                contract_address=ctx.starknet_contract_address,
                bytecode_len=ctx.return_data_len,
                bytecode=ctx.return_data,
            );
            return calling_context;
        }
    }
}

namespace SelfDestructHelper {
    // @notice A helper for SELFDESTRUCT operation.
    //         It overwrites contract account bytecode with 0s
    //         remove contract from registry
    // @param ctx The pointer to the calling context.
    // @return ExecutionContext The pointer to the updated execution_context.
    func finalize{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
    }(ctx: model.ExecutionContext*) -> model.ExecutionContext* {
        alloc_locals;

        let empty_destroy_contracts = Helpers.erase_contracts(
            ctx.destroy_contracts_len, ctx.destroy_contracts
        );
        let (empty_create_addresses: felt*) = alloc();
        let (empty_events: model.Event*) = alloc();
        let (revert_contract_state_dict_start) = default_dict_new(0);
        tempvar revert_contract_state: model.RevertContractState* = new model.RevertContractState(
            revert_contract_state_dict_start, revert_contract_state_dict_start
        );

        return new model.ExecutionContext(
            call_context=ctx.call_context,
            program_counter=ctx.program_counter,
            stopped=ctx.stopped,
            return_data=ctx.return_data,
            return_data_len=ctx.return_data_len,
            stack=ctx.stack,
            memory=ctx.memory,
            gas_used=ctx.gas_used,
            gas_limit=ctx.gas_limit,
            gas_price=ctx.gas_price,
            starknet_contract_address=ctx.starknet_contract_address,
            evm_contract_address=ctx.evm_contract_address,
            origin=ctx.origin,
            calling_context=ctx.calling_context,
            destroy_contracts_len=0,
            destroy_contracts=empty_destroy_contracts,
            events_len=0,
            events=empty_events,
            create_addresses_len=0,
            create_addresses=empty_create_addresses,
            revert_contract_state=revert_contract_state,
            reverted=FALSE,
            read_only=FALSE,
        );
    }
}
